// Toolkit service-account smoke: identify actor, read template file, create a throwaway
// destination folder, then POST /2.0/docgen_batches via box.DocGenToolkit.
// Synthetic payload only. Do not log JWT material, request JSON, or raw error bodies.

new HrDocGenSaSmoke().run();

class HrDocGenSaSmoke {
    private String templateFileId = '2456566806586';
    private String templateVersionId = '2724134783386';
    private String approvedRootId = '372250559857';
    private String smokeFolderName = 'HR_DocGen_SA_Smoke_20260909';

    public void run() {
        List<BoxJWTConfig__mdt> jwtConfigs = [
            SELECT DeveloperName, MasterLabel
            FROM BoxJWTConfig__mdt
            LIMIT 5
        ];
        System.debug(LoggingLevel.INFO, 'SA_SMOKE jwtConfigCount=' + jwtConfigs.size());
        for (BoxJWTConfig__mdt cfg : jwtConfigs) {
            System.debug(LoggingLevel.INFO, 'SA_SMOKE jwtConfig=' + cfg.DeveloperName + ' label=' + cfg.MasterLabel);
        }

        box.Toolkit toolkit = new box.Toolkit();
        String configuredRoot = toolkit.getRootFolderId();
        System.debug(LoggingLevel.INFO, 'SA_SMOKE configuredRoot=' + configuredRoot);

        HttpResponse meResp = sendBox(toolkit, 'GET', 'https://api.box.com/2.0/users/me?fields=id,type,name,login', null, false);
        summarizeUser(meResp);

        HttpResponse fileResp = sendBox(
            toolkit,
            'GET',
            'https://api.box.com/2.0/files/' + templateFileId + '?fields=id,name,type,parent,file_version',
            null,
            false
        );
        summarizeFile(fileResp);

        HttpResponse templatesResp = sendBox(toolkit, 'GET', 'https://api.box.com/2.0/docgen_templates?limit=1', null, true);
        System.debug(LoggingLevel.INFO, 'SA_SMOKE docgen_templates_status=' + httpStatus(templatesResp));

        String destinationFolderId = createOrFindSmokeFolder(toolkit);
        System.debug(LoggingLevel.INFO, 'SA_SMOKE destinationFolderId=' + destinationFolderId);

        if (String.isBlank(destinationFolderId)) {
            System.debug(LoggingLevel.ERROR, 'SA_SMOKE abort=no_destination_folder');
            return;
        }

        try {
            box.DocGenRequest request = new box.DocGenRequest();
            request.file = new box.DocGenRequest.Entity('file');
            request.file.id = templateFileId;
            request.file_version = new box.DocGenRequest.Entity('file_version');
            request.file_version.id = templateVersionId;
            request.destination_folder = new box.DocGenRequest.Entity('folder');
            request.destination_folder.id = destinationFolderId;
            request.output_type = 'pdf';

            box.DocGenRequest.document_generation_data entry = new box.DocGenRequest.document_generation_data();
            entry.generated_file_name = 'HR Request - SA-SMOKE';
            entry.user_input = syntheticUserInput();
            request.document_generation_data = new List<box.DocGenRequest.document_generation_data>{ entry };

            box.DocGenResponse response = new box.DocGenToolkit().submitDocGenBatch(request);
            if (response == null) {
                System.debug(LoggingLevel.ERROR, 'SA_SMOKE submit=null');
            } else {
                System.debug(LoggingLevel.INFO, 'SA_SMOKE submit_id=' + response.id);
                System.debug(LoggingLevel.INFO, 'SA_SMOKE submit_status=' + response.status);
                System.debug(LoggingLevel.INFO, 'SA_SMOKE submit_job_status=' + response.job_status);
            }
        } catch (box.DocGenException de) {
            System.debug(LoggingLevel.ERROR, 'SA_SMOKE submit=DocGenException type=' + de.getTypeName());
        } catch (System.CalloutException ce) {
            System.debug(LoggingLevel.ERROR, 'SA_SMOKE submit=CalloutException type=' + ce.getTypeName());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SA_SMOKE submit=Exception type=' + e.getTypeName());
        }
    }

    private HttpResponse sendBox(box.Toolkit toolkit, String method, String endpoint, String body, Boolean docgenVersion) {
        HttpRequest req = new HttpRequest();
        req.setMethod(method);
        req.setEndpoint(endpoint);
        req.setHeader('Accept', 'application/json');
        if (docgenVersion) {
            req.setHeader('box-version', '2025.0');
        }
        if (body != null) {
            req.setHeader('Content-Type', 'application/json');
            req.setBody(body);
        }
        HttpResponse resp = toolkit.sendRequest(req);
        if (resp == null) {
            System.debug(LoggingLevel.ERROR, 'SA_SMOKE sendRequest_null method=' + method);
        }
        return resp;
    }

    private String httpStatus(HttpResponse resp) {
        return resp == null ? 'null' : String.valueOf(resp.getStatusCode());
    }

    private void summarizeUser(HttpResponse resp) {
        System.debug(LoggingLevel.INFO, 'SA_SMOKE users_me_status=' + httpStatus(resp));
        if (resp == null || String.isBlank(resp.getBody())) {
            return;
        }
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            System.debug(
                LoggingLevel.INFO,
                'SA_SMOKE actor type=' + parsed.get('type')
                    + ' id=' + parsed.get('id')
                    + ' name=' + parsed.get('name')
                    + ' login=' + parsed.get('login')
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SA_SMOKE users_me_parse=failed');
        }
    }

    private void summarizeFile(HttpResponse resp) {
        System.debug(LoggingLevel.INFO, 'SA_SMOKE file_status=' + httpStatus(resp));
        if (resp == null || String.isBlank(resp.getBody()) || resp.getStatusCode() >= 400) {
            return;
        }
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            Map<String, Object> parent = (Map<String, Object>) parsed.get('parent');
            Map<String, Object> version = (Map<String, Object>) parsed.get('file_version');
            System.debug(
                LoggingLevel.INFO,
                'SA_SMOKE file id=' + parsed.get('id')
                    + ' name=' + parsed.get('name')
                    + ' parent=' + (parent == null ? null : parent.get('id'))
                    + ' version=' + (version == null ? null : version.get('id'))
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SA_SMOKE file_parse=failed');
        }
    }

    private String createOrFindSmokeFolder(box.Toolkit toolkit) {
        Map<String, Object> body = new Map<String, Object>{
            'name' => smokeFolderName,
            'parent' => new Map<String, Object>{ 'id' => approvedRootId }
        };
        HttpResponse created = sendBox(
            toolkit,
            'POST',
            'https://api.box.com/2.0/folders',
            JSON.serialize(body),
            false
        );
        Integer status = created == null ? 0 : created.getStatusCode();
        System.debug(LoggingLevel.INFO, 'SA_SMOKE folder_create_status=' + status);
        if (created != null && status >= 200 && status < 300 && String.isNotBlank(created.getBody())) {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(created.getBody());
            return (String) parsed.get('id');
        }
        if (status == 409) {
            HttpResponse listing = sendBox(
                toolkit,
                'GET',
                'https://api.box.com/2.0/folders/' + approvedRootId + '/items?limit=100&fields=id,name',
                null,
                false
            );
            System.debug(LoggingLevel.INFO, 'SA_SMOKE folder_list_status=' + httpStatus(listing));
            if (listing != null && listing.getStatusCode() < 400 && String.isNotBlank(listing.getBody())) {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(listing.getBody());
                List<Object> entries = (List<Object>) parsed.get('entries');
                if (entries != null) {
                    for (Object row : entries) {
                        Map<String, Object> item = (Map<String, Object>) row;
                        if (smokeFolderName.equals((String) item.get('name'))) {
                            return (String) item.get('id');
                        }
                    }
                }
            }
        }
        return null;
    }

    private Map<String, Object> syntheticUserInput() {
        return new Map<String, Object>{
            'schema' => new Map<String, Object>{ 'key' => 'newHire', 'version' => '1.0' },
            'case' => new Map<String, Object>{ 'id' => '500gK00000EXAMPLE', 'caseNumber' => 'SA-SMOKE' },
            'request' => new Map<String, Object>{ 'requestDate' => '2026-09-09', 'notificationType' => 'newHireRehire' },
            'employee' => new Map<String, Object>{ 'employeeId' => 'E-10042', 'firstName' => 'Jordan', 'lastName' => 'Rivera' },
            'assignment' => new Map<String, Object>{
                'region' => 'Central',
                'district' => 'District 4',
                'station' => 'Station 12',
                'startDate' => '2026-10-05',
                'isRehire' => false,
                'primaryTitle' => 'Paramedic',
                'isDualRole' => false,
                'department' => 'Operations',
                'status' => 'New Hire',
                'manager' => 'Alex Morgan',
                'employmentStatus' => 'Full Time'
            },
            'certification' => new Map<String, Object>{
                'level' => 'EMT-Paramedic',
                'txdshsNumber' => 'TX-88421',
                'priorStateDetails' => 'NM-44109'
            },
            'compensation' => new Map<String, Object>{
                'currentHourlyOrSalary' => 'Above minimum',
                'rateReason' => 'Market adjustment'
            },
            'notes' => 'Synthetic demo notes.',
            'submitter' => new Map<String, Object>{
                'name' => 'Sam Patel',
                'jobTitle' => 'Operations Supervisor',
                'email' => 'sam.patel@example.test',
                'attested' => true
            }
        };
    }
}
