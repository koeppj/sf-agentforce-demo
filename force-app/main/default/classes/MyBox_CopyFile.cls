/**
 * @description Invocable action to copy a Box file into a target Box folder using Box Toolkit for Salesforce.
 * @author Agentforce
 * @group Box
 * @since 1.0
 *
 * Usage: Expose to Flow. Provide source Box File Id and destination Box Folder Id.
 */
public with sharing class MyBox_CopyFile {
    /**
     * Constants for HTTP and headers.
     */
    public enum HttpMethod { POST }
    public enum HeaderName { content_type }
    public enum ContentType { application_json }

    /**
     * Invocable input contract.
     */
    public class Request {
        @InvocableVariable(required=true)
        public String fileId;

        @InvocableVariable(required=true)
        public String destinationFolderId;
    }

    /**
     * Invocable output contract.
     */
    public class Response {
        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public Integer statusCode;

        @InvocableVariable
        public String message;

        @InvocableVariable
        public String newFileId;

        @InvocableVariable
        public String rawResponse;
    }

    /**
     * Invocable method entry point for Flow.
     * Processes each request independently and returns a 1:1 list of results.
     */
    @InvocableMethod(label='Copy Box File to Folder' description='Copies a Box file (by File ID) to a destination Box folder (by Folder ID) using Box Toolkit.')
    public static List<Response> copyFiles(List<Request> requests) {
        List<Response> results = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            Response r = new Response();
            r.success = false;
            r.statusCode = 400;
            r.message = 'No requests provided.';
            results.add(r);
            return results;
        }

        for (Request req : requests) {
            results.add(handleSingle(req));
        }
        return results;
    }

    /**
     * Handles a single copy operation using Box Toolkit's authenticated sendRequest flow.
     * Builds POST https://api.box.com/2.0/files/{fileId}/copy with JSON body:
     * { "parent": { "id": "<destinationFolderId>" } }
     */
    private static Response handleSingle(Request req) {
        Response out = new Response();

        // Validate input (return-early)
        if (req == null) {
            out.success = false;
            out.statusCode = 400;
            out.message = 'Request is null.';
            return out;
        }
        if (String.isBlank(req.fileId)) {
            out.success = false;
            out.statusCode = 400;
            out.message = 'fileId is required.';
            return out;
        }
        if (String.isBlank(req.destinationFolderId)) {
            out.success = false;
            out.statusCode = 400;
            out.message = 'destinationFolderId is required.';
            return out;
        }

        try {
            // Instantiate Box Toolkit (handles auth)
            box.Toolkit toolkit = new box.Toolkit();

            // Endpoint: POST /2.0/files/{fileId}/copy
            String endpoint = 'https://api.box.com/2.0/files/' + req.fileId + '/copy';

            // Build JSON body
            Map<String, Object> body = new Map<String, Object>{
                'parent' => new Map<String, Object>{ 'id' => req.destinationFolderId }
            };
            String bodyJson = JSON.serialize(body);

            // Prepare HTTP request
            HttpRequest httpReq = new HttpRequest();
            httpReq.setMethod(HttpMethod.POST.name());
            httpReq.setEndpoint(endpoint);
            httpReq.setBody(bodyJson);
            httpReq.setHeader('content-type', 'application/json');

            // Send request via Toolkit
            HttpResponse httpRes = toolkit.sendRequest(httpReq);

            out.statusCode = httpRes != null ? httpRes.getStatusCode() : 0;
            out.rawResponse = httpRes != null ? httpRes.getBody() : null;

            // Success per Box API: 201 Created returns file object with "id"
            if (httpRes != null && httpRes.getStatusCode() == 201) {
                out.success = true;

                // Parse new file id from response
                try {
                    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                    Object idVal = parsed != null ? parsed.get('id') : null;
                    if (idVal != null) {
                        out.newFileId = String.valueOf(idVal);
                    }
                } catch (Exception parseEx) {
                    // Keep success=true; parsing failure only affects newFileId population
                }

                out.message = 'File copied successfully.';
                return out;
            }

            // Non-201: treat as failure, capture message
            out.success = false;
            out.message = 'Box copy failed. Status=' + String.valueOf(out.statusCode);
            return out;

        } catch (Exception e) {
            out.success = false;
            out.statusCode = 500;
            out.message = 'Unhandled exception during Box copy: ' + e.getMessage();
            return out;
        }
    }
}