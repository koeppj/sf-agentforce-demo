/**
 * @description Synchronous, callout-capable invocable action that validates a transient HR intake field
 *              collection against the active schema configuration and submits one Box Doc Gen batch.
 *              Performs no Case DML - Flow owns all Case writes. Never logs the request DTOs, the
 *              assembled JSON, or raw Box responses. Configure the Flow Action element that calls this
 *              method to start a new transaction so prior managed-package DML is committed before this
 *              callout.
 * @group MyBox
 */
public with sharing class MyBox_SubmitTransientCaseDocGen {
    private static final String ELIGIBLE_STATUS = 'Case Created';
    private static final String STATUS_SUBMITTED = 'Doc Gen Submitted';
    private static final String STATUS_SUBMIT_FAILED = 'Doc Gen Submit Failed';
    private static final String STATUS_SUBMISSION_UNKNOWN = 'Submission Unknown';

    @TestVisible
    private static MyBox_DocGenBoxAdapter adapter = new MyBox_DocGenBoxAdapterImpl();

    public class Request {
        @InvocableVariable(required=true label='Case Id')
        public Id caseId;

        @InvocableVariable(required=true label='Box Folder Id')
        public String boxFolderId;

        @InvocableVariable(required=true label='Schema Key')
        public String schemaKey;

        @InvocableVariable(required=true label='Schema Version')
        public String schemaVersion;

        @InvocableVariable(required=true label='Field Values')
        public List<MyBox_DocGenFieldValue> fieldValues;

        public Request() {
        }
    }

    public class Response {
        @InvocableVariable(label='Batch Id')
        public String batchId;

        @InvocableVariable(label='Status')
        public String status;

        @InvocableVariable(label='Error Code')
        public String errorCode;

        public Response() {
        }
    }

    @InvocableMethod(
        label='Submit Transient Case Doc Gen'
        description='Validates and synchronously submits a transient HR intake Doc Gen request for an intake-managed Case. Performs one Box callout; start a new transaction on this action.'
        category='MyBox'
        callout=true
    )
    public static List<Response> submit(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : (requests == null ? new List<Request>() : requests)) {
            results.add(handleSingle(req));
        }
        return results;
    }

    private static Response handleSingle(Request req) {
        Response out = new Response();
        try {
            if (
                req == null ||
                req.caseId == null ||
                String.isBlank(req.boxFolderId) ||
                String.isBlank(req.schemaKey) ||
                String.isBlank(req.schemaVersion)
            ) {
                throw MyBox_DocGenValidationException.of('REQUEST_INCOMPLETE', 'caseId, boxFolderId, schemaKey, and schemaVersion are required.');
            }

            Case managedCase = loadEligibleCase(req.caseId, req.schemaKey, req.schemaVersion);
            verifyFolderAssociation(req.caseId, req.boxFolderId);

            HR_DocGen_Schema__mdt schema = MyBox_DocGenSchemaService.loadActiveSchema(req.schemaKey, req.schemaVersion);
            List<HR_DocGen_Field__mdt> fieldDefs = MyBox_DocGenSchemaService.loadFieldDefinitions(schema.Id);
            Map<String, Object> userInput = MyBox_DocGenSchemaService.buildUserInputMap(
                schema,
                fieldDefs,
                managedCase.Id,
                managedCase.CaseNumber,
                req.fieldValues
            );

            box.DocGenResponse response = submitToBox(schema, req.boxFolderId, userInput);

            out.batchId = response != null ? response.id : null;
            out.status = STATUS_SUBMITTED;
        } catch (MyBox_DocGenValidationException ve) {
            out.status = STATUS_SUBMIT_FAILED;
            out.errorCode = ve.errorCode;
        } catch (box.DocGenException de) {
            out.status = STATUS_SUBMIT_FAILED;
            out.errorCode = 'DOCGEN_REJECTED';
        } catch (System.CalloutException ce) {
            out.status = STATUS_SUBMISSION_UNKNOWN;
            out.errorCode = 'DOCGEN_SUBMIT_UNKNOWN';
        } catch (Exception e) {
            out.status = STATUS_SUBMISSION_UNKNOWN;
            out.errorCode = 'UNEXPECTED_ERROR';
        }
        return out;
    }

    private static Case loadEligibleCase(Id caseId, String schemaKey, String schemaVersion) {
        List<Case> cases = [
            SELECT Id, CaseNumber, HR_Intake_Managed_Provisioning__c, HR_Integration_Status__c,
                   HR_Request_Schema_Key__c, HR_Request_Schema_Version__c, Box_DocGen_Batch_Id__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw MyBox_DocGenValidationException.of('CASE_NOT_FOUND', 'Case is not accessible.');
        }

        Case managedCase = cases[0];
        if (managedCase.HR_Intake_Managed_Provisioning__c != true) {
            throw MyBox_DocGenValidationException.of('CASE_NOT_INTAKE_MANAGED', 'Case is not intake-managed.');
        }
        if (managedCase.HR_Request_Schema_Key__c != schemaKey || managedCase.HR_Request_Schema_Version__c != schemaVersion) {
            throw MyBox_DocGenValidationException.of('SCHEMA_MISMATCH', 'Submitted schema does not match the Case schema pointer.');
        }
        if (String.isNotBlank(managedCase.Box_DocGen_Batch_Id__c)) {
            throw MyBox_DocGenValidationException.of('CASE_ALREADY_SUBMITTED', 'Case already has a Doc Gen batch.');
        }
        if (managedCase.HR_Integration_Status__c != ELIGIBLE_STATUS) {
            throw MyBox_DocGenValidationException.of('CASE_INELIGIBLE_STATE', 'Case is not in an eligible state for submission.');
        }
        return managedCase;
    }

    private static void verifyFolderAssociation(Id caseId, String boxFolderId) {
        String associatedFolderId = new box.Toolkit().getFolderIdByRecordId(caseId);
        if (String.isBlank(associatedFolderId) || associatedFolderId != boxFolderId) {
            throw MyBox_DocGenValidationException.of('FOLDER_MISMATCH', 'Supplied folder does not match the Case folder association.');
        }
    }

    private static box.DocGenResponse submitToBox(HR_DocGen_Schema__mdt schema, String boxFolderId, Map<String, Object> userInput) {
        box.DocGenRequest request = new box.DocGenRequest();

        request.file = new box.DocGenRequest.Entity('file');
        request.file.id = schema.Box_DocGen_Template_File_Id__c;

        request.file_version = new box.DocGenRequest.Entity('file_version');
        request.file_version.id = schema.Box_DocGen_Template_Version_Id__c;

        request.destination_folder = new box.DocGenRequest.Entity('folder');
        request.destination_folder.id = boxFolderId;

        request.output_type = schema.Output_Type__c;

        box.DocGenRequest.document_generation_data entry = new box.DocGenRequest.document_generation_data();
        entry.generated_file_name = buildFileName(schema.Output_File_Name_Pattern__c, (String) ((Map<String, Object>) userInput.get('case')).get('caseNumber'));
        entry.user_input = userInput;
        request.document_generation_data = new List<box.DocGenRequest.document_generation_data>{ entry };

        return adapter.submitDocGenBatch(request);
    }

    private static String buildFileName(String pattern, String caseNumber) {
        String safePattern = String.isBlank(pattern) ? 'HR Request - {caseNumber}' : pattern;
        return safePattern.replace('{caseNumber}', String.isBlank(caseNumber) ? '' : caseNumber);
    }
}
