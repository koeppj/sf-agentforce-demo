/**
 * @description Focused tests for the transient submission action: Case/schema/folder authorization
 *              guards, and normalized success/failure outcomes. Box callouts are replaced with a stub
 *              MyBox_DocGenBoxAdapter so no HTTP callout is made. The success-path and Box-outcome tests
 *              require the myBoxTestHarness/1.0 HR_DocGen_Schema__mdt/HR_DocGen_Field__mdt records to be
 *              deployed; the Case/folder authorization guard tests do not.
 * @group MyBox
 */
@IsTest
private class MyBox_SubmitTransientCaseDocGenTest {
    private class StubAdapter implements MyBox_DocGenBoxAdapter {
        public box.DocGenResponse responseToReturn;
        public Exception exceptionToThrow;

        public box.DocGenResponse submitDocGenBatch(box.DocGenRequest request) {
            if (exceptionToThrow != null) {
                throw exceptionToThrow;
            }
            return responseToReturn;
        }

        public box.DocGenResponse getDocGenBatch(String batchId) {
            return responseToReturn;
        }
    }

    private static Case createManagedCase(String schemaKey, String schemaVersion, String status, String batchId, Boolean managed) {
        Case c = new Case(
            Subject = 'HR Request',
            Status = 'New',
            HR_Request_Schema_Key__c = schemaKey,
            HR_Request_Schema_Version__c = schemaVersion,
            HR_Integration_Status__c = status,
            HR_Intake_Managed_Provisioning__c = managed,
            Box_DocGen_Batch_Id__c = batchId
        );
        insert c;
        return c;
    }

    private static void associateFolder(Id caseId, String folderId) {
        insert new box__FRUP__c(box__Record_ID__c = caseId, box__Folder_ID__c = folderId);
    }

    private static MyBox_SubmitTransientCaseDocGen.Request buildRequest(Id caseId, String folderId, String schemaKey, String schemaVersion) {
        MyBox_SubmitTransientCaseDocGen.Request req = new MyBox_SubmitTransientCaseDocGen.Request();
        req.caseId = caseId;
        req.boxFolderId = folderId;
        req.schemaKey = schemaKey;
        req.schemaVersion = schemaVersion;
        req.fieldValues = new List<MyBox_DocGenFieldValue>();
        return req;
    }

    @IsTest
    static void testSubmit_incompleteRequestRejected() {
        MyBox_SubmitTransientCaseDocGen.Request req = new MyBox_SubmitTransientCaseDocGen.Request();
        req.fieldValues = new List<MyBox_DocGenFieldValue>();

        Test.startTest();
        List<MyBox_SubmitTransientCaseDocGen.Response> results = MyBox_SubmitTransientCaseDocGen.submit(new List<MyBox_SubmitTransientCaseDocGen.Request>{ req });
        Test.stopTest();

        System.assertEquals('Doc Gen Submit Failed', results[0].status);
        System.assertEquals('REQUEST_INCOMPLETE', results[0].errorCode);
    }

    @IsTest
    static void testSubmit_caseNotIntakeManagedRejected() {
        Case c = createManagedCase('newHire', '1.0', 'Case Created', null, false);
        associateFolder(c.Id, 'folder123');
        MyBox_SubmitTransientCaseDocGen.Request req = buildRequest(c.Id, 'folder123', 'newHire', '1.0');

        Test.startTest();
        List<MyBox_SubmitTransientCaseDocGen.Response> results = MyBox_SubmitTransientCaseDocGen.submit(new List<MyBox_SubmitTransientCaseDocGen.Request>{ req });
        Test.stopTest();

        System.assertEquals('Doc Gen Submit Failed', results[0].status);
        System.assertEquals('CASE_NOT_INTAKE_MANAGED', results[0].errorCode);
    }

    @IsTest
    static void testSubmit_schemaMismatchRejected() {
        Case c = createManagedCase('newHire', '1.0', 'Case Created', null, true);
        associateFolder(c.Id, 'folder123');
        MyBox_SubmitTransientCaseDocGen.Request req = buildRequest(c.Id, 'folder123', 'newHire', '1.1');

        Test.startTest();
        List<MyBox_SubmitTransientCaseDocGen.Response> results = MyBox_SubmitTransientCaseDocGen.submit(new List<MyBox_SubmitTransientCaseDocGen.Request>{ req });
        Test.stopTest();

        System.assertEquals('Doc Gen Submit Failed', results[0].status);
        System.assertEquals('SCHEMA_MISMATCH', results[0].errorCode);
    }

    @IsTest
    static void testSubmit_alreadySubmittedRejected() {
        Case c = createManagedCase('newHire', '1.0', 'Case Created', 'existingBatch', true);
        associateFolder(c.Id, 'folder123');
        MyBox_SubmitTransientCaseDocGen.Request req = buildRequest(c.Id, 'folder123', 'newHire', '1.0');

        Test.startTest();
        List<MyBox_SubmitTransientCaseDocGen.Response> results = MyBox_SubmitTransientCaseDocGen.submit(new List<MyBox_SubmitTransientCaseDocGen.Request>{ req });
        Test.stopTest();

        System.assertEquals('Doc Gen Submit Failed', results[0].status);
        System.assertEquals('CASE_ALREADY_SUBMITTED', results[0].errorCode);
    }

    @IsTest
    static void testSubmit_ineligibleStateRejected() {
        Case c = createManagedCase('newHire', '1.0', 'Doc Gen Processing', null, true);
        associateFolder(c.Id, 'folder123');
        MyBox_SubmitTransientCaseDocGen.Request req = buildRequest(c.Id, 'folder123', 'newHire', '1.0');

        Test.startTest();
        List<MyBox_SubmitTransientCaseDocGen.Response> results = MyBox_SubmitTransientCaseDocGen.submit(new List<MyBox_SubmitTransientCaseDocGen.Request>{ req });
        Test.stopTest();

        System.assertEquals('Doc Gen Submit Failed', results[0].status);
        System.assertEquals('CASE_INELIGIBLE_STATE', results[0].errorCode);
    }

    @IsTest
    static void testSubmit_folderMismatchRejected() {
        Case c = createManagedCase('newHire', '1.0', 'Case Created', null, true);
        associateFolder(c.Id, 'folder123');
        MyBox_SubmitTransientCaseDocGen.Request req = buildRequest(c.Id, 'someOtherFolder', 'newHire', '1.0');

        Test.startTest();
        List<MyBox_SubmitTransientCaseDocGen.Response> results = MyBox_SubmitTransientCaseDocGen.submit(new List<MyBox_SubmitTransientCaseDocGen.Request>{ req });
        Test.stopTest();

        System.assertEquals('Doc Gen Submit Failed', results[0].status);
        System.assertEquals('FOLDER_MISMATCH', results[0].errorCode);
    }

    @IsTest
    static void testSubmit_unknownSchemaRejected() {
        Case c = createManagedCase('doesNotExist', '9.9', 'Case Created', null, true);
        associateFolder(c.Id, 'folder123');
        MyBox_SubmitTransientCaseDocGen.Request req = buildRequest(c.Id, 'folder123', 'doesNotExist', '9.9');

        Test.startTest();
        List<MyBox_SubmitTransientCaseDocGen.Response> results = MyBox_SubmitTransientCaseDocGen.submit(new List<MyBox_SubmitTransientCaseDocGen.Request>{ req });
        Test.stopTest();

        System.assertEquals('Doc Gen Submit Failed', results[0].status);
        System.assertEquals('SCHEMA_UNKNOWN_OR_INACTIVE', results[0].errorCode);
    }

    @IsTest
    static void testSubmit_successReturnsBatchId() {
        Case c = createManagedCase('myBoxTestHarness', '1.0', 'Case Created', null, true);
        associateFolder(c.Id, 'folder123');
        MyBox_SubmitTransientCaseDocGen.Request req = buildRequest(c.Id, 'folder123', 'myBoxTestHarness', '1.0');
        req.fieldValues.add(makeText('employee.firstName', 'Jane'));
        req.fieldValues.add(makeDate('assignment.startDate', Date.newInstance(2026, 9, 21)));
        req.fieldValues.add(makeBool('submitter.attested', true));

        box.DocGenResponse mockResponse = new box.DocGenResponse();
        mockResponse.id = 'batch-001';
        StubAdapter stub = new StubAdapter();
        stub.responseToReturn = mockResponse;
        MyBox_SubmitTransientCaseDocGen.adapter = stub;

        Test.startTest();
        List<MyBox_SubmitTransientCaseDocGen.Response> results = MyBox_SubmitTransientCaseDocGen.submit(new List<MyBox_SubmitTransientCaseDocGen.Request>{ req });
        Test.stopTest();

        System.assertEquals('Doc Gen Submitted', results[0].status);
        System.assertEquals('batch-001', results[0].batchId);
        System.assertEquals(null, results[0].errorCode);
    }

    @IsTest
    static void testSubmit_boxDefiniteRejectionMapsToSubmitFailed() {
        Case c = createManagedCase('myBoxTestHarness', '1.0', 'Case Created', null, true);
        associateFolder(c.Id, 'folder123');
        MyBox_SubmitTransientCaseDocGen.Request req = buildRequest(c.Id, 'folder123', 'myBoxTestHarness', '1.0');
        req.fieldValues.add(makeText('employee.firstName', 'Jane'));
        req.fieldValues.add(makeDate('assignment.startDate', Date.newInstance(2026, 9, 21)));
        req.fieldValues.add(makeBool('submitter.attested', true));

        StubAdapter stub = new StubAdapter();
        stub.exceptionToThrow = new box.DocGenException('simulated definite rejection');
        MyBox_SubmitTransientCaseDocGen.adapter = stub;

        Test.startTest();
        List<MyBox_SubmitTransientCaseDocGen.Response> results = MyBox_SubmitTransientCaseDocGen.submit(new List<MyBox_SubmitTransientCaseDocGen.Request>{ req });
        Test.stopTest();

        System.assertEquals('Doc Gen Submit Failed', results[0].status);
        System.assertEquals('DOCGEN_REJECTED', results[0].errorCode);
    }

    @IsTest
    static void testSubmit_calloutExceptionMapsToSubmissionUnknown() {
        Case c = createManagedCase('myBoxTestHarness', '1.0', 'Case Created', null, true);
        associateFolder(c.Id, 'folder123');
        MyBox_SubmitTransientCaseDocGen.Request req = buildRequest(c.Id, 'folder123', 'myBoxTestHarness', '1.0');
        req.fieldValues.add(makeText('employee.firstName', 'Jane'));
        req.fieldValues.add(makeDate('assignment.startDate', Date.newInstance(2026, 9, 21)));
        req.fieldValues.add(makeBool('submitter.attested', true));

        StubAdapter stub = new StubAdapter();
        stub.exceptionToThrow = new System.CalloutException('simulated timeout');
        MyBox_SubmitTransientCaseDocGen.adapter = stub;

        Test.startTest();
        List<MyBox_SubmitTransientCaseDocGen.Response> results = MyBox_SubmitTransientCaseDocGen.submit(new List<MyBox_SubmitTransientCaseDocGen.Request>{ req });
        Test.stopTest();

        System.assertEquals('Submission Unknown', results[0].status);
        System.assertEquals('DOCGEN_SUBMIT_UNKNOWN', results[0].errorCode);
    }

    private static MyBox_DocGenFieldValue makeText(String path, String value) {
        MyBox_DocGenFieldValue fv = new MyBox_DocGenFieldValue();
        fv.path = path;
        fv.valueType = 'text';
        fv.textValue = value;
        return fv;
    }

    private static MyBox_DocGenFieldValue makeDate(String path, Date value) {
        MyBox_DocGenFieldValue fv = new MyBox_DocGenFieldValue();
        fv.path = path;
        fv.valueType = 'date';
        fv.dateValue = value;
        return fv;
    }

    private static MyBox_DocGenFieldValue makeBool(String path, Boolean value) {
        MyBox_DocGenFieldValue fv = new MyBox_DocGenFieldValue();
        fv.path = path;
        fv.valueType = 'boolean';
        fv.booleanValue = value;
        return fv;
    }
}
