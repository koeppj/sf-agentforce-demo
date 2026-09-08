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
| Candidate user A | `005gK000074cosVQAQ` | `johnkoepp@gmail.com` | Customer Community Plus Login User | Default Help Center | Present; **not** assigned `MyBox_HR_DocGen_Access` |
| Candidate user B | — | — | — | — | **Outstanding.** No second Customer Community Plus (or equivalent) user exists. |

Internal Standard users `jkoepp+demo3@box.com` and `jkoepp+demo4@boxdemo.com` are not Experience community users.

Chunk 6 cannot complete the cross-user Case/folder isolation check until user B is created, licensed, added to Default Help Center, and given the same least-privilege access as user A.

## Case sharing and access

| Item | Value |
| --- | --- |
| Case internal OWD | ReadWriteTransfer |
| Case external OWD | Private |
| Active Case record types | `Portal_Request` only |
| HR intake Case | No dedicated record type. Intake should create a generic Case (blank/default record type), Subject `HR Request`, Description blank |

External Private sharing means Experience user B should not see user A's Cases if A owns the Case. Confirm Community Plus users can **create and own** Case records during chunk 6. Do not populate Case Contact or employee fields from the form.

`MyBox_HR_DocGen_Access` currently grants FLS on the seven orchestration fields only and is assigned to admin John Koepp. Experience users still need:

- Apex class access: `MyBox_SubmitTransientCaseDocGen`, `MyBox_GetCaseDocGenStatus`
- Flow access for `HR_New_Hire_Intake` and `HR_Check_DocGen_Status` (Draft in org; do not activate until chunk 6)
- Case Create and Read
- Box for Salesforce Experience / App User permissions
- The Box App User (Experience Cloud) arrangement from [Box UI Elements in Experience Cloud](https://support.box.com/hc/en-us/articles/26032384109075-Setting-up-Box-UI-Elements-in-Experience-Cloud)

## Competing Case-folder automation

`Create_Box_Folder_for_New_Case` is **Active** (unmanaged). Source: `force-app/main/default/flows/Create_Box_Folder_for_New_Case.flow-meta.xml`. Do not activate intake until this Flow excludes intake-managed Cases (chunk 6).

Current behavior (simplified 8 Sep 2026; no folder template):

- Record-triggered after-save on Case **create**, async after commit.
- Entry filter: `RecordTypeId` is blank **or** null. HR intake Cases with no record type **will match** and can race with the intake Flow's synchronous folder create.
- Calls `box__CreateFolderForRecordId_v2` with `folderNameOverride` = Case number and `optCreateRootFolder = true`.

Chunk 6 change: add a condition that `HR_Intake_Managed_Provisioning__c` is not true (and keep the existing record-type filter). Do not disable the Flow for Portal Request / internal intake.

Other unmanaged Case/Box Flows in the org (do not change unless they copy form data or provision intake folders): `Box_Assign_Case_Collaborator`, `Collaborate_Case_Team_to_Case_Folder`, `Process_Box_File_Upload_Events`, `Portal_User_Box_Folder_Component`, `On_Case_Close`, Case Team delete Flows.

## Box content root and folder template

CLI actor used for inspection: Box user `35570754363` (`jkoepp+admin@boxdemo.com`). This is **not** automatically the Salesforce Toolkit service account. Verify service-account access to the same root before publishing the chunk 2 template.

| Item | Box Id | Name |
| --- | --- | --- |
| Approved demo root | `372250559857` | Salesforce and AgenForce Root |
| Folder templates parent | `372728063567` | Folder Template |
| Existing Case folder template | `372728243760` | Case Template |
| Cases object folder | `372727880485` | Cases |
| Existing record-based Doc Gen folder | `389691397233` | Box Doc Gen Templates |

Intake and the competing Case Flow **do not** use a folder template. `372728243760` remains the existing Case Template in Box if something else still needs it. `HR_DocGen_Schema__mdt.Box_Folder_Template_Id__c` is unused by the current Flows. Keep `NewHire_1_0` **Draft** until chunk 6 writes Doc Gen **file/version** IDs and activates the schema.

Existing Salesforce `box__DocGen_Template__c` rows (`Default Case Info`, `New and Improved Case Summary`) are **record-based Case templates**. Do not use them for this intake. JSON `user_input` submission goes through `box.DocGenToolkit.submitDocGenBatch`.

## Documented package interfaces (no spike classes)

Use these from the installed 5.56 package. Signatures were verified in the prior Apex pass.

| Capability | Interface | Notes |
| --- | --- | --- |
| Create Case folder | Flow action `box__CreateFolderForRecordId_v2` | Inputs: `recordId`, optional `folderNameOverride`, optional `optCreateRootFolder`. Output includes `folderId`. Intake starts a new Flow transaction. No template. |
| Folder association | `box.Toolkit.getFolderIdByRecordId(caseId)` and managed `box__FRUP__c` | Do not add `Box_Folder_Id__c` to Case. |
| Submit Doc Gen JSON | `box.DocGenToolkit.submitDocGenBatch` via `MyBox_SubmitTransientCaseDocGen` | `box.DocGenRequest` properties: `file`, `file_version`, `destination_folder`, `output_type`, `document_generation_data`. No `input_source` property on the request type. |
| Status | `box.DocGenToolkit.getDocGenBatch` via `MyBox_GetCaseDocGenStatus` | Normalized outputs only. Do not persist raw `DocGenResponse`. |
| Upload / preview | Managed Box Content Uploader and Content Explorer | Experience page settings: preview, upload, download on; delete, rename, share, folder create off. |

Doc Gen REST `GET /2.0/docgen_templates` returned HTTP 404 for the CLI actor (with and without `box-version: 2025.0`). Treat **JSON Doc Gen entitlement / API access for the runtime identity** as outstanding. Record-based Doc Gen templates already exist in Salesforce, so package Doc Gen is enabled in some form; that does not prove the batch JSON API for the service account.

See [Box Doc Gen setup](https://support.box.com/hc/en-us/articles/48670280271635-Setting-up-Box-Doc-Gen-in-Salesforce) and [Generate documents](https://developer.box.com/guides/docgen/generate-document).

## Salesforce artifacts already deployed

Present in `agentforce-demo`:

- All `MyBox_*` submission/status/schema classes (API 66, package version box 5.56); invocables marked `callout=true`
- Seven Case orchestration fields
- `HR_DocGen_Schema__mdt` and `HR_DocGen_Field__mdt` **types**
- Permission set `MyBox_HR_DocGen_Access` (Case FLS only)
- Draft Flows `HR_New_Hire_Intake` and `HR_Check_DocGen_Status`
- Active simplified `Create_Box_Folder_for_New_Case`

Custom Metadata **records** are in the org (4 schema versions, 37 field records). `sf project deploy start --metadata CustomMetadata:...` still fails with `UNKNOWN_EXCEPTION` (example ErrorId `1877119324-716804 (-315522575)`). Workaround that works: `Metadata.Operations.enqueueDeployment` from anonymous Apex, one small batch at a time. Field `MasterLabel` must be 40 characters or fewer (source labels were shortened to `NH1.0 {path}` / `H1.0 {path}`).

## Outstanding setup (blocks chunk 2 publication or chunk 6 acceptance)

1. Second synthetic Experience user (user B) with Community Plus (or equivalent) license, site membership, and least-privilege access.
2. Assign intake permissions to users A and B (Apex, Flow, Case, Box App User). Do not use the admin permission-set assignment as the demo runtime.
3. Confirm Box Doc Gen JSON/batch API entitlement for the **Toolkit service account**, including write access under root `372250559857`.
4. Confirm Experience Cloud Box UI Elements (Client Credentials Grant app, CORS, App User mapping) on Default Help Center.
5. Create Custom Metadata records in Setup until Metadata API record deploy works.
6. Chunk 6: exclude `HR_Intake_Managed_Provisioning__c = true` from `Create_Box_Folder_for_New_Case` before activating intake.

Independent source authoring (Flows, contract, Apex tests against in-memory metadata) is not blocked by items 1–4.

## Next chunk

Resume from [hr_request_demo_status.md](hr_request_demo_status.md). Next build work is chunk 2 (Box Doc Gen template + service-account JSON API), then chunk 6 (Experience wiring, intake exclusion, first live run).
