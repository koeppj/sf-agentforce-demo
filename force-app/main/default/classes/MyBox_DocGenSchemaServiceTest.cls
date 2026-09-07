/**
 * @description Focused tests for the generic HR intake Doc Gen validator/serializer. Field definitions
 *              and schema records are constructed in memory (Custom Metadata Type sObjects can be
 *              instantiated without DML) so this suite does not depend on any deployed
 *              HR_DocGen_Schema__mdt/HR_DocGen_Field__mdt configuration.
 * @group MyBox
 */
@IsTest
private class MyBox_DocGenSchemaServiceTest {
    private static HR_DocGen_Schema__mdt schema(Double maxPayloadBytes) {
        return new HR_DocGen_Schema__mdt(
            Schema_Key__c = 'unitTest',
            Version__c = '1.0',
            Lifecycle_Status__c = 'Active',
            Max_Payload_Bytes__c = maxPayloadBytes
        );
    }

    private static HR_DocGen_Field__mdt fieldDef(String path, String valueType, Boolean required, String blankBehavior, Double maxLength, String allowedValues) {
        return new HR_DocGen_Field__mdt(
            Json_Path__c = path,
            Value_Type__c = valueType,
            Required__c = required,
            Blank_Behavior__c = blankBehavior,
            Max_Length__c = maxLength,
            Allowed_Values__c = allowedValues,
            Sequence__c = 10
        );
    }

    private static MyBox_DocGenFieldValue textValue(String path, String value) {
        MyBox_DocGenFieldValue fv = new MyBox_DocGenFieldValue();
        fv.path = path;
        fv.valueType = 'text';
        fv.textValue = value;
        return fv;
    }

    private static MyBox_DocGenFieldValue dateValue(String path, Date value) {
        MyBox_DocGenFieldValue fv = new MyBox_DocGenFieldValue();
        fv.path = path;
        fv.valueType = 'date';
        fv.dateValue = value;
        return fv;
    }

    private static MyBox_DocGenFieldValue numberValue(String path, Decimal value) {
        MyBox_DocGenFieldValue fv = new MyBox_DocGenFieldValue();
        fv.path = path;
        fv.valueType = 'number';
        fv.numberValue = value;
        return fv;
    }

    private static MyBox_DocGenFieldValue boolValue(String path, Boolean value) {
        MyBox_DocGenFieldValue fv = new MyBox_DocGenFieldValue();
        fv.path = path;
        fv.valueType = 'boolean';
        fv.booleanValue = value;
        return fv;
    }

    @IsTest
    static void testLoadActiveSchema_blankInputRejected() {
        try {
            MyBox_DocGenSchemaService.loadActiveSchema('', '1.0');
            System.assert(false, 'Expected a validation exception for blank schema key.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('SCHEMA_UNKNOWN_OR_INACTIVE', ve.errorCode);
        }
    }

    @IsTest
    static void testLoadActiveSchema_unknownSchemaRejected() {
        try {
            MyBox_DocGenSchemaService.loadActiveSchema('doesNotExist', '9.9');
            System.assert(false, 'Expected a validation exception for an unknown schema.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('SCHEMA_UNKNOWN_OR_INACTIVE', ve.errorCode);
        }
    }

    @IsTest
    static void testBuildUserInputMap_fullSuccessAndBooleanFalseIsAValue() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>{
            fieldDef('employee.firstName', 'text', true, 'null', 80, null),
            fieldDef('employee.middleName', 'text', false, 'omit', null, null),
            fieldDef('assignment.startDate', 'date', true, 'null', null, null),
            fieldDef('assignment.isDualRole', 'boolean', false, 'null', null, '[true,false]'),
            fieldDef('compensation.currentHourlyOrSalary', 'text', false, 'emptyString', 20, null),
            fieldDef('submitter.attested', 'boolean', true, 'null', null, '[true]'),
            fieldDef('notes', 'text', false, 'emptyString', 500, null)
        };
        List<MyBox_DocGenFieldValue> values = new List<MyBox_DocGenFieldValue>{
            textValue('employee.firstName', 'Jane'),
            dateValue('assignment.startDate', Date.newInstance(2026, 9, 21)),
            boolValue('assignment.isDualRole', false),
            boolValue('submitter.attested', true)
        };

        Test.startTest();
        Map<String, Object> result = MyBox_DocGenSchemaService.buildUserInputMap(schema(null), defs, '500000000000001AAA', 'CASE-0001', values);
        Test.stopTest();

        Map<String, Object> employee = (Map<String, Object>) result.get('employee');
        System.assertEquals('Jane', employee.get('firstName'));
        System.assert(!employee.containsKey('middleName'), 'Optional omitted field must be excluded entirely.');

        Map<String, Object> assignment = (Map<String, Object>) result.get('assignment');
        System.assertEquals(Boolean.valueOf(false), assignment.get('isDualRole'));

        Map<String, Object> compensation = (Map<String, Object>) result.get('compensation');
        System.assertEquals('', compensation.get('currentHourlyOrSalary'));

        System.assertEquals('', result.get('notes'));

        Map<String, Object> schemaBlock = (Map<String, Object>) result.get('schema');
        System.assertEquals('unitTest', schemaBlock.get('key'));
        Map<String, Object> caseBlock = (Map<String, Object>) result.get('case');
        System.assertEquals('CASE-0001', caseBlock.get('caseNumber'));
    }

    @IsTest
    static void testBuildUserInputMap_missingRequiredRejected() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>{
            fieldDef('employee.firstName', 'text', true, 'null', null, null)
        };
        try {
            MyBox_DocGenSchemaService.buildUserInputMap(schema(null), defs, '500000000000001AAA', 'CASE-0001', new List<MyBox_DocGenFieldValue>());
            System.assert(false, 'Expected a validation exception for a missing required value.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('MISSING_REQUIRED', ve.errorCode);
        }
    }

    @IsTest
    static void testBuildUserInputMap_unknownPathRejected() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>{
            fieldDef('employee.firstName', 'text', false, 'omit', null, null)
        };
        List<MyBox_DocGenFieldValue> values = new List<MyBox_DocGenFieldValue>{
            textValue('employee.unknownField', 'x')
        };
        try {
            MyBox_DocGenSchemaService.buildUserInputMap(schema(null), defs, '500000000000001AAA', 'CASE-0001', values);
            System.assert(false, 'Expected a validation exception for an unknown path.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('UNKNOWN_PATH', ve.errorCode);
        }
    }

    @IsTest
    static void testBuildUserInputMap_duplicatePathRejected() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>{
            fieldDef('notes', 'text', false, 'omit', null, null)
        };
        List<MyBox_DocGenFieldValue> values = new List<MyBox_DocGenFieldValue>{
            textValue('notes', 'first'),
            textValue('notes', 'second')
        };
        try {
            MyBox_DocGenSchemaService.buildUserInputMap(schema(null), defs, '500000000000001AAA', 'CASE-0001', values);
            System.assert(false, 'Expected a validation exception for a duplicate path.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('DUPLICATE_PATH', ve.errorCode);
        }
    }

    @IsTest
    static void testBuildUserInputMap_reservedRootRejected() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>();
        List<MyBox_DocGenFieldValue> values = new List<MyBox_DocGenFieldValue>{
            textValue('schema.key', 'x')
        };
        try {
            MyBox_DocGenSchemaService.buildUserInputMap(schema(null), defs, '500000000000001AAA', 'CASE-0001', values);
            System.assert(false, 'Expected a validation exception for a reserved root path.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('RESERVED_PATH', ve.errorCode);
        }
    }

    @IsTest
    static void testBuildUserInputMap_invalidPathSyntaxRejected() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>();
        List<MyBox_DocGenFieldValue> values = new List<MyBox_DocGenFieldValue>{
            textValue('Employee.FirstName', 'x')
        };
        try {
            MyBox_DocGenSchemaService.buildUserInputMap(schema(null), defs, '500000000000001AAA', 'CASE-0001', values);
            System.assert(false, 'Expected a validation exception for invalid path syntax.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('INVALID_PATH_SYNTAX', ve.errorCode);
        }
    }

    @IsTest
    static void testBuildUserInputMap_typeMismatchRejected() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>{
            fieldDef('employee.firstName', 'text', false, 'omit', null, null)
        };
        List<MyBox_DocGenFieldValue> values = new List<MyBox_DocGenFieldValue>{
            numberValue('employee.firstName', 5)
        };
        try {
            MyBox_DocGenSchemaService.buildUserInputMap(schema(null), defs, '500000000000001AAA', 'CASE-0001', values);
            System.assert(false, 'Expected a validation exception for a type mismatch.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('TYPE_MISMATCH', ve.errorCode);
        }
    }

    @IsTest
    static void testBuildUserInputMap_valueTooLongRejected() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>{
            fieldDef('notes', 'text', false, 'omit', 5, null)
        };
        List<MyBox_DocGenFieldValue> values = new List<MyBox_DocGenFieldValue>{
            textValue('notes', 'this value is too long')
        };
        try {
            MyBox_DocGenSchemaService.buildUserInputMap(schema(null), defs, '500000000000001AAA', 'CASE-0001', values);
            System.assert(false, 'Expected a validation exception for a value exceeding max length.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('VALUE_TOO_LONG', ve.errorCode);
        }
    }

    @IsTest
    static void testBuildUserInputMap_valueNotAllowedRejected() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>{
            fieldDef('submitter.attested', 'boolean', true, 'null', null, '[true]')
        };
        List<MyBox_DocGenFieldValue> values = new List<MyBox_DocGenFieldValue>{
            boolValue('submitter.attested', false)
        };
        try {
            MyBox_DocGenSchemaService.buildUserInputMap(schema(null), defs, '500000000000001AAA', 'CASE-0001', values);
            System.assert(false, 'Expected a validation exception for a disallowed value.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('VALUE_NOT_ALLOWED', ve.errorCode);
        }
    }

    @IsTest
    static void testBuildUserInputMap_pathCollisionRejected() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>{
            fieldDef('employee', 'text', false, 'omit', null, null),
            fieldDef('employee.firstName', 'text', false, 'omit', null, null)
        };
        List<MyBox_DocGenFieldValue> values = new List<MyBox_DocGenFieldValue>{
            textValue('employee', 'scalar'),
            textValue('employee.firstName', 'Jane')
        };
        try {
            MyBox_DocGenSchemaService.buildUserInputMap(schema(null), defs, '500000000000001AAA', 'CASE-0001', values);
            System.assert(false, 'Expected a validation exception for a scalar/object path collision.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('PATH_COLLISION', ve.errorCode);
        }
    }

    @IsTest
    static void testBuildUserInputMap_payloadTooLargeRejected() {
        List<HR_DocGen_Field__mdt> defs = new List<HR_DocGen_Field__mdt>{
            fieldDef('notes', 'text', false, 'omit', null, null)
        };
        List<MyBox_DocGenFieldValue> values = new List<MyBox_DocGenFieldValue>{
            textValue('notes', 'some non-empty content')
        };
        try {
            MyBox_DocGenSchemaService.buildUserInputMap(schema(10), defs, '500000000000001AAA', 'CASE-0001', values);
            System.assert(false, 'Expected a validation exception for an oversized payload.');
        } catch (MyBox_DocGenValidationException ve) {
            System.assertEquals('PAYLOAD_TOO_LARGE', ve.errorCode);
        }
    }
}
