# HR Request Demo — Environment Readiness

Non-secret configuration for the New Hire/Rehire intake described in [hr_request_demo_tooling.md](hr_request_demo_tooling.md). Reviewed against org alias `agentforce-demo` and the authenticated Box CLI actor on 8 Sep 2026. Session progress: [hr_request_demo_status.md](hr_request_demo_status.md). Credentials, tokens, JWT material, and request payloads are not recorded here.

## Target Salesforce org

| Item | Value |
| --- | --- |
| CLI alias | `agentforce-demo` (default) |
| Username | `jkoepp+admin.5871147628f3@agentforce.com` |
| Org Id | `00DgK00000LNIJVUA5` |
| Instance | `https://orgfarm-d01c8c3fa9-dev-ed.develop.my.salesforce.com` |
| Edition | Developer Edition (OrgFarm) |
| API version (CLI display) | 67.0 |
| Project source API | 66.0 |

Other authenticated aliases (`box-sandbox`, `mia-sandbox`) are **not** the target. `box-sandbox` has Box for Salesforce 5.32.5.1; this design was compiled against 5.56.

## Installed Box package

| Item | Value |
| --- | --- |
| Package | Box for Salesforce |
| Namespace | `box` |
| Version | 5.56.0.1 |
| Also installed | Box Agents 1.10.0.1 |

JWT/service-account configuration exists as Custom Metadata `BoxJWTConfig__mdt.Default_Config`. Do not export that record. Runtime Box identity for Toolkit callouts is the package service account configured in that record, not the interactive CLI user.

## Experience Cloud

| Site | Status | Network Id | Path | URL |
| --- | --- | --- | --- | --- |
| **Default Help Center** (target) | Live | `0DBgK000001GudZWAS` | `/portal` | `https://orgfarm-d01c8c3fa9-dev-ed.develop.my.site.com/portal` |
| Customer Portal | UnderConstruction | `0DBgK000001rh9VWAQ` | `/customers` | not used for this demo |
| Box Integration | Live | `0DBgK000001bnIvWAI` | `/box` | package site; not the intake UI |

My Domain site host: `orgfarm-d01c8c3fa9-dev-ed.develop.my.site.com`.

Default Help Center members (User Ids only): `005gK00002fMSe7QAG` (OrgFarm EPIC, System Administrator), `005gK00002jHJR5QAO` (John Koepp, System Administrator), `005gK000074cosVQAQ` (Customer Community Plus Login User), `005gK00007bdp8bQAA` (Fred Johnson, Service Supervisor).

### Synthetic Experience users

The plan requires two synthetic Experience users for submitter vs isolation checks.

| Role | User Id | Username | Profile | Network member? | Status |
| --- | --- | --- | --- | --- | --- |
| Candidate user A | `005gK000074cosVQAQ` | `johnkoepp@gmail.com` | Customer Community Plus Login User | Default Help Center | Present; assigned `MyBox_HR_DocGen_Access` and `box__Box_App_User` |
| Candidate user B | `005gK00007dqzzXQAQ` | `riley.chen.hrdemo.b@example.test` | Customer Community Plus Login User | Default Help Center | Present; Account `001gK00001STqVdQAL` (HR Demo Isolation B); assigned `MyBox_HR_DocGen_Access` and `box__Box_App_User` |

Internal Standard users `jkoepp+demo3@box.com` and `jkoepp+demo4@boxdemo.com` are not Experience community users.

Chunk 6 wiring is in place. Remaining acceptance is the live Experience submission and isolation checks in [hr_request_demo_integration_results.md](hr_request_demo_integration_results.md).

## Case sharing and access

| Item | Value |
| --- | --- |
| Case internal OWD | ReadWriteTransfer |
| Case external OWD | Private |
| Active Case record types | `Portal_Request` only |
| HR intake Case | No dedicated record type. Intake should create a generic Case (blank/default record type), Subject `HR Request`, Description blank |

External Private sharing means Experience user B should not see user A's Cases if A owns the Case. Confirm Community Plus users can **create and own** Case records during chunk 6. Do not populate Case Contact or employee fields from the form.

`MyBox_HR_DocGen_Access` grants Case FLS on the seven orchestration fields, Apex/Flow access, Case create/read/edit, and Run Flow. It is assigned to admin John Koepp and Experience users A and B. `box__Box_App_User` is assigned directly to A and B. See [Box UI Elements in Experience Cloud](https://support.box.com/hc/en-us/articles/26032384109075-Setting-up-Box-UI-Elements-in-Experience-Cloud) if the explorer/uploader fails to load.

## Competing Case-folder automation

`Create_Box_Folder_for_New_Case` is **Active** (unmanaged). Source: `force-app/main/default/flows/Create_Box_Folder_for_New_Case.flow-meta.xml`. Intake-managed Cases are excluded.

Current behavior (simplified 8 Sep 2026; no folder template):

- Record-triggered after-save on Case **create**, async after commit.
- Entry filter: `RecordTypeId` is blank **or** null, **and** `HR_Intake_Managed_Provisioning__c` is not true.
- Calls `box__CreateFolderForRecordId_v2` with `folderNameOverride` = Case number and `optCreateRootFolder = true`.

Chunk 6 applied that exclusion before activating intake. Do not disable the Flow for Portal Request / internal intake.

Other unmanaged Case/Box Flows in the org (do not change unless they copy form data or provision intake folders): `Box_Assign_Case_Collaborator`, `Collaborate_Case_Team_to_Case_Folder`, `Process_Box_File_Upload_Events`, `Portal_User_Box_Folder_Component`, `On_Case_Close`, Case Team delete Flows.

## Box content root and folder template

CLI actor used for inspection: Box user `35570754363` (`jkoepp+admin@boxdemo.com`). Runtime Toolkit identity is service account `49821057233` (`Salesforce AgentForce User`). On 9 Sep 2026 that service account **can** `GET` file `2456566806586`, list Doc Gen templates, write under root `372250559857`, and complete `POST /2.0/docgen_batches` (batch `dfadffe5-250e-43d9-a0ab-beb8dcbb5f5b`, output `2456627065285`). `GET /2.0/docgen_templates` still HTTP 404 for the CLI OAuth app.

| Item | Box Id | Name |
| --- | --- | --- |
| Approved demo root | `372250559857` | Salesforce and AgenForce Root |
| Folder templates parent | `372728063567` | Folder Template |
| Existing Case folder template | `372728243760` | Case Template |
| Cases object folder | `372727880485` | Cases |
| Existing record-based Doc Gen folder | `389691397233` | Box Doc Gen Templates |
| **JSON Doc Gen template (`newHire/1.0`)** | `2456566806586` | `new_hire_box_docgen.docx`. Version `2724134783386`. Parent `389691397233`. Operator-tested 9 Sep 2026. Prior ID `456566806586` was a typo. |

Intake and the competing Case Flow **do not** use a folder template. `372728243760` remains the existing Case Template in Box if something else still needs it. `HR_DocGen_Schema__mdt.Box_Folder_Template_Id__c` is unused by the current Flows. `NewHire_1_0` is **Active** with file `2456566806586` and version `2724134783386`.

Existing Salesforce `box__DocGen_Template__c` rows (`Default Case Info`, `New and Improved Case Summary`) are **record-based Case templates**. Do not use them for this intake. JSON generation is [`POST /2.0/docgen_batches`](https://developer.box.com/reference/v2025.0/post-docgen-batches) (`document_generation_data[].user_input`); Salesforce runtime calls it through `box.DocGenToolkit.submitDocGenBatch`. Synthetic merge example: [examples/newHire_1_0_user_input.json](examples/newHire_1_0_user_input.json). Manifest: [hr_request_demo_template_manifest.md](hr_request_demo_template_manifest.md).

## Documented package interfaces (no spike classes)

Use these from the installed 5.56 package. Signatures were verified in the prior Apex pass.

| Capability | Interface | Notes |
| --- | --- | --- |
| Create Case folder | Flow action `box__CreateFolderForRecordId_v2` | Inputs: `recordId`, optional `folderNameOverride`, optional `optCreateRootFolder`. Output includes `folderId`. Intake starts a new Flow transaction. No template. |
| Folder association | `box.Toolkit.getFolderIdByRecordId(caseId)` and managed `box__FRUP__c` | Do not add `Box_Folder_Id__c` to Case. |
| Submit Doc Gen JSON | `box.DocGenToolkit.submitDocGenBatch` via `MyBox_SubmitTransientCaseDocGen` | Wrapper for [`POST /2.0/docgen_batches`](https://developer.box.com/reference/v2025.0/post-docgen-batches). `box.DocGenRequest` properties: `file`, `file_version`, `destination_folder`, `output_type`, `document_generation_data` (`generated_file_name` + `user_input`). REST still requires `input_source: "api"`; the Apex type does not expose that property. |
| Status | `box.DocGenToolkit.getDocGenBatch` via `MyBox_GetCaseDocGenStatus` | Wrapper for [`GET /2.0/docgen_batch_jobs/{batch_id}`](https://developer.box.com/reference/v2025.0/get-docgen-batch-jobs-id). Normalized outputs only. Do not persist raw `DocGenResponse`. |
| Upload / preview | Managed Box Content Uploader and Content Explorer | Experience page settings: preview, upload, download on; delete, rename, share, folder create off. |

Doc Gen REST `GET /2.0/docgen_templates` still HTTP 404 for the CLI OAuth app. The Toolkit **service account** can list templates and complete JSON batch generation. Record-based Doc Gen templates also exist in Salesforce.

See [Box Doc Gen setup](https://support.box.com/hc/en-us/articles/48670280271635-Setting-up-Box-Doc-Gen-in-Salesforce), [`POST /2.0/docgen_batches`](https://developer.box.com/reference/v2025.0/post-docgen-batches), and [Generate documents](https://developer.box.com/guides/docgen/generate-document).

## Salesforce artifacts already deployed

Present in `agentforce-demo`:

- All `MyBox_*` submission/status/schema classes (API 66, package version box 5.56); invocables marked `callout=true`
- Seven Case orchestration fields
- `HR_DocGen_Schema__mdt` and `HR_DocGen_Field__mdt` **types**
- Permission set `MyBox_HR_DocGen_Access` (FLS, Apex, Flow, Case CRUD)
- Active Flows `HR_New_Hire_Intake` and `HR_Check_DocGen_Status`
- Active simplified `Create_Box_Folder_for_New_Case` with intake exclusion

Custom Metadata **records** are in the org (4 schema versions, 37 field records). `sf project deploy start --metadata CustomMetadata:...` still fails with `UNKNOWN_EXCEPTION` (example ErrorId `1877119324-716804 (-315522575)`). Workaround that works: `Metadata.Operations.enqueueDeployment` from anonymous Apex, one small batch at a time. Field `MasterLabel` must be 40 characters or fewer (source labels were shortened to `NH1.0 {path}` / `H1.0 {path}`).

## Outstanding setup (blocks chunk 6 acceptance)

1. First Experience end-to-end run as user A (synthetic PDF + upload + status refresh) and user B isolation.
2. If UI Elements fail to load: confirm Experience CCG app, CORS, and App User mapping (not exported).
3. Custom Metadata record deploys: use Apex `Metadata.Operations.enqueueDeployment` until Metadata API record deploy works.

Independent source authoring for chunks 7–8 is not blocked.

## Next chunk

Resume from [hr_request_demo_status.md](hr_request_demo_status.md). Chunk 6 wiring is done; live Experience acceptance remains. After that, chunks 7–8.
