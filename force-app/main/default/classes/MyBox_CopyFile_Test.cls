/**
 * @description Unit tests for MyBox_CopyFile invocable class.
 * Creates a mocked HTTP callout via HttpCalloutMock to simulate Box Toolkit behavior.
 * Validates success and error paths with meaningful assertions.
 */
@IsTest
private class MyBox_CopyFile_Test {
    @TestSetup
    static void setup() {
        // No org data required. Inputs are simple strings.
    }

    /**
     * Mock for the Box Toolkit callout. The Toolkit ultimately uses Http under the hood,
     * so we can simulate responses with HttpCalloutMock.
     */
    private class BoxCopySuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod(), 'HTTP method must be POST');
            System.assert(req.getEndpoint().contains('/2.0/files/'), 'Endpoint should target Box files API');
            System.assert(req.getEndpoint().endsWith('/copy'), 'Endpoint must end with /copy');
            System.assertEquals('application/json', req.getHeader('content-type'), 'Content-Type must be application/json');
            System.assertNotEquals(null, req.getBody(), 'Body should be provided');

            // Simulate Box 201 Created with new file id in JSON body
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"type":"file","id":"999999","name":"CopiedFile.pdf"}');
            return res;
        }
    }

    private class BoxCopyFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"type":"error","status":400,"code":"invalid_request_parameters"}');
            return res;
        }
    }

    @IsTest
    static void testSuccessCopySingle() {
        Test.setMock(HttpCalloutMock.class, new BoxCopySuccessMock());

        MyBox_CopyFile.Request r = new MyBox_CopyFile.Request();
        r.fileId = '12345';
        r.destinationFolderId = '67890';

        Test.startTest();
        List<MyBox_CopyFile.Response> out = MyBox_CopyFile.copyFiles(new List<MyBox_CopyFile.Request>{ r });
        Test.stopTest();

        System.assertEquals(1, out.size(), 'Should return one response');
        System.assertEquals(true, out[0].success, 'Success should be true');
        System.assertEquals(201, out[0].statusCode, 'Status code should be 201 for created');
        System.assertEquals('999999', out[0].newFileId, 'New file id should be parsed from response');
        System.assertNotEquals(null, out[0].rawResponse, 'Raw response should be captured');
        System.assertEquals('File copied successfully.', out[0].message, 'Success message should be set');
    }

    @IsTest
    static void testFailureCopySingle() {
        Test.setMock(HttpCalloutMock.class, new BoxCopyFailureMock());

        MyBox_CopyFile.Request r = new MyBox_CopyFile.Request();
        r.fileId = 'bad';
        r.destinationFolderId = '67890';

        Test.startTest();
        List<MyBox_CopyFile.Response> out = MyBox_CopyFile.copyFiles(new List<MyBox_CopyFile.Request>{ r });
        Test.stopTest();

        System.assertEquals(1, out.size(), 'Should return one response');
        System.assertEquals(false, out[0].success, 'Success should be false');
        System.assertEquals(400, out[0].statusCode, 'Status code should be propagated');
        System.assert(out[0].message.startsWith('Box copy failed.'), 'Failure message should indicate failure');
        System.assertNotEquals(null, out[0].rawResponse, 'Raw response should be captured');
        System.assertEquals(null, out[0].newFileId, 'New file id should not be set on failure');
    }

    @IsTest
    static void testInputValidation() {
        // Null list
        Test.startTest();
        List<MyBox_CopyFile.Response> out1 = MyBox_CopyFile.copyFiles(null);
        Test.stopTest();
        System.assertEquals(1, out1.size(), 'On null input, should return one response with error');
        System.assertEquals(false, out1[0].success);
        System.assertEquals(400, out1[0].statusCode);
        System.assertEquals('No requests provided.', out1[0].message);

        // Missing fileId
        MyBox_CopyFile.Request r1 = new MyBox_CopyFile.Request();
        r1.fileId = null;
        r1.destinationFolderId = '67890';

        // Missing folder
        MyBox_CopyFile.Request r2 = new MyBox_CopyFile.Request();
        r2.fileId = '12345';
        r2.destinationFolderId = null;

        // Provide a mock—for validation path, Toolkit isn't invoked, but safe to set.
        Test.setMock(HttpCalloutMock.class, new BoxCopySuccessMock());

        Test.startTest();
        List<MyBox_CopyFile.Response> out2 = MyBox_CopyFile.copyFiles(new List<MyBox_CopyFile.Request>{ r1, r2 });
        Test.stopTest();

        System.assertEquals(2, out2.size(), 'Should return two results');
        System.assertEquals(false, out2[0].success);
        System.assertEquals(400, out2[0].statusCode);
        System.assertEquals('fileId is required.', out2[0].message);

        System.assertEquals(false, out2[1].success);
        System.assertEquals(400, out2[1].statusCode);
        System.assertEquals('destinationFolderId is required.', out2[1].message);
    }

    @IsTest
    static void testMultipleRequests_MixedResults() {
        // First will succeed, second will fail. We alternate behavior via a composite mock if needed.
        // Simpler: run two separate calls to keep mocks clear.

        // Success case
        Test.setMock(HttpCalloutMock.class, new BoxCopySuccessMock());
        MyBox_CopyFile.Request ok = new MyBox_CopyFile.Request();
        ok.fileId = 'A';
        ok.destinationFolderId = 'F1';

        Test.startTest();
        List<MyBox_CopyFile.Response> okOut = MyBox_CopyFile.copyFiles(new List<MyBox_CopyFile.Request>{ ok });
        Test.stopTest();
        System.assertEquals(true, okOut[0].success);

        // Failure case
        Test.setMock(HttpCalloutMock.class, new BoxCopyFailureMock());
        MyBox_CopyFile.Request bad = new MyBox_CopyFile.Request();
        bad.fileId = 'B';
        bad.destinationFolderId = 'F2';

        Test.startTest();
        List<MyBox_CopyFile.Response> badOut = MyBox_CopyFile.copyFiles(new List<MyBox_CopyFile.Request>{ bad });
        Test.stopTest();
        System.assertEquals(false, badOut[0].success);
    }
}