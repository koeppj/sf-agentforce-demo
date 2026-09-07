/**
 * @description Focused tests for the manual Doc Gen status wrapper. Box callouts are replaced with a
 *              stub MyBox_DocGenBoxAdapter so no HTTP callout is made and no dependency on deployed
 *              schema configuration is required.
 * @group MyBox
 */
@IsTest
private class MyBox_GetCaseDocGenStatusTest {
    private class StubAdapter implements MyBox_DocGenBoxAdapter {
        public box.DocGenResponse responseToReturn;
        public Exception exceptionToThrow;

        public box.DocGenResponse submitDocGenBatch(box.DocGenRequest request) {
            return null;
        }

        public box.DocGenResponse getDocGenBatch(String batchId) {
            if (exceptionToThrow != null) {
                throw exceptionToThrow;
            }
            return responseToReturn;
        }
    }

    private static Case createCase(Boolean managed, String batchId) {
        Case c = new Case(
            Subject = 'HR Request',
            Status = 'New',
            HR_Intake_Managed_Provisioning__c = managed,
            Box_DocGen_Batch_Id__c = batchId
        );
        insert c;
        return c;
    }

    private static MyBox_GetCaseDocGenStatus.Request buildRequest(Id caseId) {
        MyBox_GetCaseDocGenStatus.Request req = new MyBox_GetCaseDocGenStatus.Request();
        req.caseId = caseId;
        return req;
    }

    private static box.DocGenResponse withStatus(String status, String outputFileId) {
        box.DocGenResponse response = new box.DocGenResponse();
        response.job_status = status;
        response.output_file_ID = outputFileId;
        return response;
    }

    @IsTest
    static void testGetStatus_caseNotFoundRejected() {
        MyBox_GetCaseDocGenStatus.Request req = buildRequest(null);

        Test.startTest();
        List<MyBox_GetCaseDocGenStatus.Response> results = MyBox_GetCaseDocGenStatus.getStatus(new List<MyBox_GetCaseDocGenStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals('CASE_NOT_FOUND', results[0].errorCode);
        System.assertEquals(null, results[0].status);
    }

    @IsTest
    static void testGetStatus_notIntakeManagedTreatedAsNotFound() {
        Case c = createCase(false, 'batch-1');
        MyBox_GetCaseDocGenStatus.Request req = buildRequest(c.Id);

        Test.startTest();
        List<MyBox_GetCaseDocGenStatus.Response> results = MyBox_GetCaseDocGenStatus.getStatus(new List<MyBox_GetCaseDocGenStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals('CASE_NOT_FOUND', results[0].errorCode);
    }

    @IsTest
    static void testGetStatus_noBatchId() {
        Case c = createCase(true, null);
        MyBox_GetCaseDocGenStatus.Request req = buildRequest(c.Id);

        Test.startTest();
        List<MyBox_GetCaseDocGenStatus.Response> results = MyBox_GetCaseDocGenStatus.getStatus(new List<MyBox_GetCaseDocGenStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals('NO_BATCH_ID', results[0].errorCode);
    }

    @IsTest
    static void testGetStatus_pending() {
        Case c = createCase(true, 'batch-1');
        StubAdapter stub = new StubAdapter();
        stub.responseToReturn = withStatus('pending', null);
        MyBox_GetCaseDocGenStatus.adapter = stub;

        Test.startTest();
        List<MyBox_GetCaseDocGenStatus.Response> results = MyBox_GetCaseDocGenStatus.getStatus(new List<MyBox_GetCaseDocGenStatus.Request>{ buildRequest(c.Id) });
        Test.stopTest();

        System.assertEquals('Doc Gen Submitted', results[0].status);
        System.assertEquals(null, results[0].errorCode);
    }

    @IsTest
    static void testGetStatus_processing() {
        Case c = createCase(true, 'batch-1');
        StubAdapter stub = new StubAdapter();
        stub.responseToReturn = withStatus('processing', null);
        MyBox_GetCaseDocGenStatus.adapter = stub;

        Test.startTest();
        List<MyBox_GetCaseDocGenStatus.Response> results = MyBox_GetCaseDocGenStatus.getStatus(new List<MyBox_GetCaseDocGenStatus.Request>{ buildRequest(c.Id) });
        Test.stopTest();

        System.assertEquals('Doc Gen Processing', results[0].status);
    }

    @IsTest
    static void testGetStatus_completedWithOutputFile() {
        Case c = createCase(true, 'batch-1');
        StubAdapter stub = new StubAdapter();
        stub.responseToReturn = withStatus('completed', 'file-999');
        MyBox_GetCaseDocGenStatus.adapter = stub;

        Test.startTest();
        List<MyBox_GetCaseDocGenStatus.Response> results = MyBox_GetCaseDocGenStatus.getStatus(new List<MyBox_GetCaseDocGenStatus.Request>{ buildRequest(c.Id) });
        Test.stopTest();

        System.assertEquals('Document Generated', results[0].status);
        System.assertEquals('file-999', results[0].outputFileId);
    }

    @IsTest
    static void testGetStatus_completedWithoutOutputFileMissing() {
        Case c = createCase(true, 'batch-1');
        StubAdapter stub = new StubAdapter();
        stub.responseToReturn = withStatus('completed', null);
        MyBox_GetCaseDocGenStatus.adapter = stub;

        Test.startTest();
        List<MyBox_GetCaseDocGenStatus.Response> results = MyBox_GetCaseDocGenStatus.getStatus(new List<MyBox_GetCaseDocGenStatus.Request>{ buildRequest(c.Id) });
        Test.stopTest();

        System.assertEquals(null, results[0].status);
        System.assertEquals('DOCGEN_OUTPUT_MISSING', results[0].errorCode);
    }

    @IsTest
    static void testGetStatus_failed() {
        Case c = createCase(true, 'batch-1');
        StubAdapter stub = new StubAdapter();
        stub.responseToReturn = withStatus('failed', null);
        MyBox_GetCaseDocGenStatus.adapter = stub;

        Test.startTest();
        List<MyBox_GetCaseDocGenStatus.Response> results = MyBox_GetCaseDocGenStatus.getStatus(new List<MyBox_GetCaseDocGenStatus.Request>{ buildRequest(c.Id) });
        Test.stopTest();

        System.assertEquals('Doc Gen Failed', results[0].status);
        System.assertEquals('DOCGEN_FAILED', results[0].errorCode);
    }

    @IsTest
    static void testGetStatus_entriesFallbackWhenTopLevelBlank() {
        Case c = createCase(true, 'batch-1');
        box.DocGenResponse response = new box.DocGenResponse();
        box.DocGenResponse.Jobs job = new box.DocGenResponse.Jobs();
        job.status = 'completed';
        box.DocGenResponse.Entity outFile = new box.DocGenResponse.Entity();
        outFile.id = 'file-from-entry';
        job.output_file = outFile;
        response.entries = new List<box.DocGenResponse.Jobs>{ job };

        StubAdapter stub = new StubAdapter();
        stub.responseToReturn = response;
        MyBox_GetCaseDocGenStatus.adapter = stub;

        Test.startTest();
        List<MyBox_GetCaseDocGenStatus.Response> results = MyBox_GetCaseDocGenStatus.getStatus(new List<MyBox_GetCaseDocGenStatus.Request>{ buildRequest(c.Id) });
        Test.stopTest();

        System.assertEquals('Document Generated', results[0].status);
        System.assertEquals('file-from-entry', results[0].outputFileId);
    }

    @IsTest
    static void testGetStatus_calloutFailureUnavailable() {
        Case c = createCase(true, 'batch-1');
        StubAdapter stub = new StubAdapter();
        stub.exceptionToThrow = new System.CalloutException('simulated timeout');
        MyBox_GetCaseDocGenStatus.adapter = stub;

        Test.startTest();
        List<MyBox_GetCaseDocGenStatus.Response> results = MyBox_GetCaseDocGenStatus.getStatus(new List<MyBox_GetCaseDocGenStatus.Request>{ buildRequest(c.Id) });
        Test.stopTest();

        System.assertEquals(null, results[0].status);
        System.assertEquals('DOCGEN_STATUS_UNAVAILABLE', results[0].errorCode);
    }
}
