/**
 * @description Schema-neutral loader/validator/serializer for the HR intake Doc Gen contract. Reads
 *              HR_DocGen_Schema__mdt/HR_DocGen_Field__mdt configuration only; has no New Hire-specific
 *              branches. Builds the nested "user_input" map entirely in Apex heap memory - the map (and
 *              the transient MyBox_DocGenFieldValue values it is built from) must never be inserted,
 *              cached, logged, or enqueued.
 * @group MyBox
 */
public with sharing class MyBox_DocGenSchemaService {
    @TestVisible
    private static final Integer MAX_PATH_SEGMENTS = 4;

    @TestVisible
    private static final Set<String> RESERVED_ROOTS = new Set<String>{ 'schema', 'case' };

    private static final Set<String> VALID_VALUE_TYPES = new Set<String>{ 'text', 'date', 'number', 'boolean' };
    private static final Set<String> VALID_BLANK_BEHAVIORS = new Set<String>{ 'emptyString', 'null', 'omit' };
    private static final Pattern PATH_SEGMENT_PATTERN = Pattern.compile('^[a-z][a-zA-Z0-9]*$');

    /**
     * @description Loads the single Active schema record for the exact key/version. Treats the caller's
     *              key/version as untrusted input.
     */
    public static HR_DocGen_Schema__mdt loadActiveSchema(String schemaKey, String schemaVersion) {
        if (String.isBlank(schemaKey) || String.isBlank(schemaVersion)) {
            throw MyBox_DocGenValidationException.of('SCHEMA_UNKNOWN_OR_INACTIVE', 'Schema key and version are required.');
        }

        List<HR_DocGen_Schema__mdt> schemas = [
            SELECT Id, Schema_Key__c, Version__c, Lifecycle_Status__c, Box_Folder_Template_Id__c,
                   Box_DocGen_Template_File_Id__c, Box_DocGen_Template_Version_Id__c, Output_Type__c,
                   Output_File_Name_Pattern__c, Max_Payload_Bytes__c
            FROM HR_DocGen_Schema__mdt
            WHERE Schema_Key__c = :schemaKey AND Version__c = :schemaVersion
            LIMIT 2
        ];

        if (schemas.size() != 1 || schemas[0].Lifecycle_Status__c != 'Active') {
            throw MyBox_DocGenValidationException.of(
                'SCHEMA_UNKNOWN_OR_INACTIVE',
                'No single active schema found for ' + schemaKey + '/' + schemaVersion + '.'
            );
        }
        return schemas[0];
    }

    /**
     * @description Loads the field definitions for one schema version. Separated from
     *              buildUserInputMap so validation logic can be exercised in tests against in-memory
     *              HR_DocGen_Field__mdt instances without requiring deployed Custom Metadata records.
     */
    public static List<HR_DocGen_Field__mdt> loadFieldDefinitions(Id schemaId) {
        return [
            SELECT Json_Path__c, Value_Type__c, Required__c, Max_Length__c, Blank_Behavior__c, Sequence__c, Allowed_Values__c
            FROM HR_DocGen_Field__mdt
            WHERE Schema__c = :schemaId
            ORDER BY Sequence__c ASC NULLS LAST
        ];
    }

    /**
     * @description Validates the supplied field-value collection against the schema's field definitions
     *              and returns the nested "user_input" map, including the non-sensitive schema/case roots.
     *              Throws MyBox_DocGenValidationException with a sanitized errorCode on any violation.
     */
    public static Map<String, Object> buildUserInputMap(
        HR_DocGen_Schema__mdt schema,
        List<HR_DocGen_Field__mdt> fieldDefs,
        Id caseId,
        String caseNumber,
        List<MyBox_DocGenFieldValue> fieldValues
    ) {
        Map<String, HR_DocGen_Field__mdt> defsByPath = indexFieldDefinitions(fieldDefs);
        Map<String, MyBox_DocGenFieldValue> suppliedByPath = mapSuppliedValues(fieldValues, defsByPath);

        Map<String, Object> root = new Map<String, Object>();
        for (HR_DocGen_Field__mdt def : defsByPath.values()) {
            applyField(root, def, suppliedByPath.get(def.Json_Path__c));
        }

        root.put('schema', new Map<String, Object>{ 'key' => schema.Schema_Key__c, 'version' => schema.Version__c });
        root.put('case', new Map<String, Object>{ 'id' => caseId, 'caseNumber' => caseNumber });

        if (schema.Max_Payload_Bytes__c != null) {
            Integer payloadSize = Blob.valueOf(JSON.serialize(root)).size();
            if (payloadSize > schema.Max_Payload_Bytes__c) {
                throw MyBox_DocGenValidationException.of('PAYLOAD_TOO_LARGE', 'Serialized payload exceeds the configured limit.');
            }
        }
        return root;
    }

    private static Map<String, HR_DocGen_Field__mdt> indexFieldDefinitions(List<HR_DocGen_Field__mdt> fieldDefs) {
        Map<String, HR_DocGen_Field__mdt> defsByPath = new Map<String, HR_DocGen_Field__mdt>();
        for (HR_DocGen_Field__mdt def : (fieldDefs == null ? new List<HR_DocGen_Field__mdt>() : fieldDefs)) {
            if (String.isBlank(def.Json_Path__c) || defsByPath.containsKey(def.Json_Path__c)) {
                throw MyBox_DocGenValidationException.of('SCHEMA_CONFIG_INVALID', 'Duplicate or blank field path in schema configuration.');
            }
            if (!isValidPathSyntax(def.Json_Path__c) || isReservedPath(def.Json_Path__c)) {
                throw MyBox_DocGenValidationException.of('SCHEMA_CONFIG_INVALID', 'Configured path is not allowed: ' + def.Json_Path__c);
            }
            defsByPath.put(def.Json_Path__c, def);
        }
        return defsByPath;
    }

    private static Map<String, MyBox_DocGenFieldValue> mapSuppliedValues(
        List<MyBox_DocGenFieldValue> fieldValues,
        Map<String, HR_DocGen_Field__mdt> defsByPath
    ) {
        Map<String, MyBox_DocGenFieldValue> suppliedByPath = new Map<String, MyBox_DocGenFieldValue>();
        for (MyBox_DocGenFieldValue fv : (fieldValues == null ? new List<MyBox_DocGenFieldValue>() : fieldValues)) {
            if (fv == null || String.isBlank(fv.path)) {
                throw MyBox_DocGenValidationException.of('UNKNOWN_PATH', 'A submitted field value is missing its path.');
            }
            if (isReservedPath(fv.path)) {
                throw MyBox_DocGenValidationException.of('RESERVED_PATH', 'Path uses a reserved root: ' + fv.path);
            }
            if (!isValidPathSyntax(fv.path)) {
                throw MyBox_DocGenValidationException.of('INVALID_PATH_SYNTAX', 'Path syntax is not allowed: ' + fv.path);
            }
            if (!defsByPath.containsKey(fv.path)) {
                throw MyBox_DocGenValidationException.of('UNKNOWN_PATH', 'Path is not part of the active schema: ' + fv.path);
            }
            if (suppliedByPath.containsKey(fv.path)) {
                throw MyBox_DocGenValidationException.of('DUPLICATE_PATH', 'Path was supplied more than once: ' + fv.path);
            }
            HR_DocGen_Field__mdt def = defsByPath.get(fv.path);
            if (def.Value_Type__c != fv.valueType) {
                throw MyBox_DocGenValidationException.of('TYPE_MISMATCH', 'Submitted type does not match schema for ' + fv.path);
            }
            if (!isSingleTypedValuePopulated(fv)) {
                throw MyBox_DocGenValidationException.of('TYPE_MISMATCH', 'Exactly one typed value must be populated for ' + fv.path);
            }
            suppliedByPath.put(fv.path, fv);
        }
        return suppliedByPath;
    }

    private static Boolean isSingleTypedValuePopulated(MyBox_DocGenFieldValue fv) {
        Integer populatedCount = 0;
        if (fv.textValue != null) {
            populatedCount++;
        }
        if (fv.dateValue != null) {
            populatedCount++;
        }
        if (fv.numberValue != null) {
            populatedCount++;
        }
        if (fv.booleanValue != null) {
            populatedCount++;
        }
        return populatedCount <= 1;
    }

    private static void applyField(Map<String, Object> root, HR_DocGen_Field__mdt def, MyBox_DocGenFieldValue fv) {
        if (!VALID_VALUE_TYPES.contains(def.Value_Type__c)) {
            throw MyBox_DocGenValidationException.of('SCHEMA_CONFIG_INVALID', 'Unsupported value type configured for ' + def.Json_Path__c);
        }
        String blankBehavior = String.isBlank(def.Blank_Behavior__c) ? 'null' : def.Blank_Behavior__c;
        if (!VALID_BLANK_BEHAVIORS.contains(blankBehavior)) {
            throw MyBox_DocGenValidationException.of('SCHEMA_CONFIG_INVALID', 'Unsupported blank behavior configured for ' + def.Json_Path__c);
        }
        if (blankBehavior == 'emptyString' && def.Value_Type__c != 'text') {
            throw MyBox_DocGenValidationException.of('SCHEMA_CONFIG_INVALID', 'emptyString blank behavior is only valid for text fields: ' + def.Json_Path__c);
        }

        Object value = fv == null ? null : extractValue(def, fv);
        Boolean isBlank = value == null || (value instanceof String && String.isBlank((String) value));

        if (isBlank) {
            if (def.Required__c == true) {
                throw MyBox_DocGenValidationException.of('MISSING_REQUIRED', 'Missing required value for ' + def.Json_Path__c);
            }
            if (blankBehavior == 'omit') {
                return;
            }
            value = blankBehavior == 'emptyString' ? '' : null;
        } else {
            validateConstraints(def, value);
        }

        setPath(root, def.Json_Path__c, value);
    }

    private static Object extractValue(HR_DocGen_Field__mdt def, MyBox_DocGenFieldValue fv) {
        if (def.Value_Type__c == 'text') {
            return fv.textValue;
        }
        if (def.Value_Type__c == 'date') {
            return fv.dateValue;
        }
        if (def.Value_Type__c == 'number') {
            return fv.numberValue;
        }
        if (def.Value_Type__c == 'boolean') {
            return fv.booleanValue;
        }
        return null;
    }

    private static void validateConstraints(HR_DocGen_Field__mdt def, Object value) {
        if (def.Value_Type__c == 'text' && def.Max_Length__c != null) {
            String textValue = (String) value;
            if (textValue.length() > def.Max_Length__c) {
                throw MyBox_DocGenValidationException.of('VALUE_TOO_LONG', 'Value exceeds the configured length for ' + def.Json_Path__c);
            }
        }
        if (String.isNotBlank(def.Allowed_Values__c)) {
            List<Object> allowedValues = (List<Object>) JSON.deserializeUntyped(def.Allowed_Values__c);
            Boolean found = false;
            for (Object candidate : allowedValues) {
                if (valuesMatch(def.Value_Type__c, value, candidate)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                throw MyBox_DocGenValidationException.of('VALUE_NOT_ALLOWED', 'Value is not in the allowed list for ' + def.Json_Path__c);
            }
        }
    }

    private static Boolean valuesMatch(String valueType, Object value, Object candidate) {
        if (valueType == 'number') {
            return ((Decimal) value) == Decimal.valueOf(String.valueOf(candidate));
        }
        if (valueType == 'boolean') {
            return ((Boolean) value) == (Boolean) candidate;
        }
        if (valueType == 'date') {
            return ((Date) value) == Date.valueOf(String.valueOf(candidate));
        }
        return String.valueOf(value) == String.valueOf(candidate);
    }

    private static Boolean isReservedPath(String path) {
        return RESERVED_ROOTS.contains(path.split('\\.')[0]);
    }

    private static Boolean isValidPathSyntax(String path) {
        List<String> segments = path.split('\\.');
        if (segments.isEmpty() || segments.size() > MAX_PATH_SEGMENTS) {
            return false;
        }
        for (String segment : segments) {
            if (!PATH_SEGMENT_PATTERN.matcher(segment).matches()) {
                return false;
            }
        }
        return true;
    }

    private static void setPath(Map<String, Object> root, String path, Object value) {
        List<String> segments = path.split('\\.');
        Map<String, Object> cursor = root;
        for (Integer i = 0; i < segments.size() - 1; i++) {
            String segment = segments[i];
            Object existing = cursor.get(segment);
            if (existing == null) {
                Map<String, Object> next = new Map<String, Object>();
                cursor.put(segment, next);
                cursor = next;
            } else if (existing instanceof Map<String, Object>) {
                cursor = (Map<String, Object>) existing;
            } else {
                throw MyBox_DocGenValidationException.of('PATH_COLLISION', 'Path collides with a scalar value: ' + path);
            }
        }
        String leaf = segments[segments.size() - 1];
        if (cursor.containsKey(leaf) && cursor.get(leaf) instanceof Map<String, Object>) {
            throw MyBox_DocGenValidationException.of('PATH_COLLISION', 'Path collides with a nested object: ' + path);
        }
        cursor.put(leaf, value);
    }
}
