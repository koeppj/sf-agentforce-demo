/**
 * @description Thin synchronous wrapper around box.DocGenToolkit.getDocGenBatch used only if the managed
 *              getDocgenBatch Flow action cannot satisfy the normalized, non-sensitive output contract.
 *              Resolves the batch ID server-side from an authorized, intake-managed Case; never accepts a
 *              batch ID from the caller and performs no Case DML. A null Response.status means "preserve
 *              the Case's prior integration status" - Flow must not overwrite state in that case.
 * @group MyBox
 */
public with sharing class MyBox_GetCaseDocGenStatus {
    private static final String RAW_PENDING = 'pending';
    private static final String RAW_PROCESSING = 'processing';
    private static final String RAW_COMPLETED = 'completed';
    private static final String RAW_FAILED = 'failed';

    @TestVisible
    private static MyBox_DocGenBoxAdapter adapter = new MyBox_DocGenBoxAdapterImpl();

    public class Request {
        @InvocableVariable(required=true label='Case Id')
        public Id caseId;

        public Request() {
        }
    }

    public class Response {
        @InvocableVariable(label='Status')
        public String status;

        @InvocableVariable(label='Output File Id')
        public String outputFileId;

        @InvocableVariable(label='Error Code')
        public String errorCode;

        public Response() {
        }
    }

    @InvocableMethod(
        label='Get Case Doc Gen Status'
        description='Returns a normalized Doc Gen status for an authorized, intake-managed Case without exposing raw Box response data. Performs one Box callout.'
        category='MyBox'
        callout=true
    )
    public static List<Response> getStatus(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : (requests == null ? new List<Request>() : requests)) {
            results.add(handleSingle(req));
        }
        return results;
    }

    private static Response handleSingle(Request req) {
        Response out = new Response();
        try {
            if (req == null || req.caseId == null) {
                out.errorCode = 'CASE_NOT_FOUND';
                return out;
            }

            List<Case> cases = [
                SELECT Id, HR_Intake_Managed_Provisioning__c, Box_DocGen_Batch_Id__c
                FROM Case
                WHERE Id = :req.caseId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (cases.isEmpty() || cases[0].HR_Intake_Managed_Provisioning__c != true) {
                out.errorCode = 'CASE_NOT_FOUND';
                return out;
            }

            String batchId = cases[0].Box_DocGen_Batch_Id__c;
            if (String.isBlank(batchId)) {
                out.errorCode = 'NO_BATCH_ID';
                return out;
            }

            box.DocGenResponse response = adapter.getDocGenBatch(batchId);
            applyNormalizedStatus(out, response);
        } catch (Exception e) {
            out.status = null;
            out.outputFileId = null;
            out.errorCode = 'DOCGEN_STATUS_UNAVAILABLE';
        }
        return out;
    }

    private static void applyNormalizedStatus(Response out, box.DocGenResponse response) {
        if (response == null) {
            out.errorCode = 'DOCGEN_STATUS_UNAVAILABLE';
            return;
        }

        String rawStatus = response.job_status;
        String outputFileId = response.output_file_ID;

        if (String.isBlank(rawStatus) && response.entries != null && !response.entries.isEmpty()) {
            box.DocGenResponse.Jobs job = response.entries[0];
            rawStatus = job.status;
            if (String.isBlank(outputFileId) && job.output_file != null) {
                outputFileId = job.output_file.id;
            }
        }
        if (String.isBlank(rawStatus)) {
            rawStatus = response.status;
        }

        String normalized = String.isBlank(rawStatus) ? '' : rawStatus.toLowerCase();

        if (normalized == RAW_PENDING) {
            out.status = 'Doc Gen Submitted';
        } else if (normalized == RAW_PROCESSING) {
            out.status = 'Doc Gen Processing';
        } else if (normalized == RAW_COMPLETED) {
            if (String.isNotBlank(outputFileId)) {
                out.status = 'Document Generated';
                out.outputFileId = outputFileId;
            } else {
                out.errorCode = 'DOCGEN_OUTPUT_MISSING';
            }
        } else if (normalized == RAW_FAILED) {
            out.status = 'Doc Gen Failed';
            out.errorCode = 'DOCGEN_FAILED';
        } else {
            out.errorCode = 'DOCGEN_STATUS_UNAVAILABLE';
        }
    }
}
