# HR Request Demo — Current State

Handoff as of **9 Sep 2026**. Target org alias: **`agentforce-demo`**. Do not use `box-sandbox` or `mia-sandbox`.

Read this first when resuming. Then [hr_request_demo_environment.md](hr_request_demo_environment.md) for org IDs, [hr_request_demo_contract.md](hr_request_demo_contract.md) for the frozen `newHire/1.0` field map, [hr_request_demo_template_manifest.md](hr_request_demo_template_manifest.md) for the Box Doc Gen template, and [hr_request_demo_integration_results.md](hr_request_demo_integration_results.md) for chunk 6 IDs. The original plan remains [hr_request_demo_tooling.md](hr_request_demo_tooling.md); folder creation has since been simplified (see below).

Synthetic HR data only. Never persist form PII on Case, Files, notes, logs, error emails, or CMDT.

## Chunk status

| Chunk | Goal | Status |
| --- | --- | --- |
| 0 | Environment handoff | **Done** in source. User B, HR/Box App User assignments, and Toolkit service-account Doc Gen are in place. Box CCG/CORS remain operator-confirm if UI Elements fail to load. |
| 1 | Contract + CMDT | **Done.** Checklist frozen. Types, 26 `newHire/1.0` fields, harness fields, and 4 schema records are in the org. `NewHire_1_0` is **Active**. Org and source have template file `2456566806586` and version `2724134783386`. |
| 2 | Box Doc Gen Word template | **Done** (operator-tested). File `2456566806586` (`new_hire_box_docgen.docx`), version `2724134783386`, under `389691397233`. Toolkit service account can generate against it. CLI OAuth still 404s on `GET /2.0/docgen_templates`. Manifest: [hr_request_demo_template_manifest.md](hr_request_demo_template_manifest.md). |
| 3 | Generic Apex submit/status | **Done** and deployed. Tests passing in org. |
| 4 | `HR_New_Hire_Intake` | **Active** in repo and org. Activation required boolean-required, rate-reason variable, and uploader visibility formula fixes. |
| 5 | `HR_Check_DocGen_Status` | **Active** in repo and org. Status formula uses `TEXT()` on the Case picklist. |
| 6 | Experience page, permissions, first live run | **Wiring done.** Exclusion live; users A/B permitted; `/hr-request` published. **First Experience end-to-end run and isolation checks remain.** |
| 7 | `newHire/1.1` + schema-demo Flow copy | **Not started.** |
| 8 | Presenter runbook | **Not started.** |

## What to do next

1. **First live Experience run** as user A at `https://orgfarm-d01c8c3fa9-dev-ed.develop.my.site.com/portal/s/hr-request` (wait for Help Center publish job `08PgK0000181a2vUAA`). Synthetic form, PDF in the Case folder, optional supporting upload, then Check Document Status. Then user B isolation. Details: [hr_request_demo_integration_results.md](hr_request_demo_integration_results.md).
2. If Box UI Elements do not load, confirm the Experience CCG app, CORS, and App User mapping in Box Admin (not exported here).
3. **Chunks 7–8** — `newHire/1.1` (`request.referenceNote`), Flow copy `HR_New_Hire_Intake_Schema_Demo`, runbook.

## Folder creation (implementation change)

Plan text still mentions `box__CreateFolderForRecordIdFromTemplate_v2`. **Do not go back to templates.**

Both Flows now call **`box__CreateFolderForRecordId_v2`** (Create Folder For Record ID):

| Flow | Status in org | Behavior |
| --- | --- | --- |
| `Create_Box_Folder_for_New_Case` | **Active** | Case create, RecordTypeId blank/null, **and** `HR_Intake_Managed_Provisioning__c != true`, async after commit. Folder name = Case number. `optCreateRootFolder = true`. No template, no Case Type parent, no `sfCaseRecord` metadata cascade. |
| `HR_New_Hire_Intake` | **Active** | After Case create, **new transaction**, same action, folder name = Case number. Folder Id stays in `vBoxFolderId` only (not a Case field). |

Intake Cases are excluded from the record-triggered Flow by `HR_Intake_Managed_Provisioning__c != true`. If both still ran, the Toolkit should reuse the record–folder association rather than cloning a template tree.

## Flows

### `HR_New_Hire_Intake` (Active)

Path: `force-app/main/default/flows/HR_New_Hire_Intake.flow-meta.xml`

- One screen, sections: Employee, Assignment, Certification, Compensation, Notes, Submitter.
- All 26 contract paths assigned into `colDocGenFields` (`MyBox_DocGenFieldValue`). Constants `cSchemaKey=newHire`, `cSchemaVersion=1.0`, `cNotificationType=newHireRehire`. `request.requestDate` = `$Flow.CurrentDate`.
- Rate reason visible/required only for `Above minimum` / `Above maximum`; otherwise cleared before Case create.
- Case shell: Subject `HR Request`, Origin `Web`, no Description/PII, `HR_Intake_Managed_Provisioning__c=true`, schema pointers, status `Case Created`.
- Submit: `MyBox_SubmitTransientCaseDocGen` in a **new transaction**. Flow writes batch Id / status / error code.
- Faults: folder → `Folder Failed`; submit fail → `Doc Gen Submit Failed`; unknown → `Submission Unknown`; Case update fail → `CASE_UPDATE_FAILED`. Never copy `$Flow.FaultMessage`.
- Receipt: Case number + integration status only; Previous disabled; `box:UIElementUpload` with `folderId={!vBoxFolderId}`. Collection cleared first.

Live submit requires `NewHire_1_0` **Active** with Box template file **and** version IDs. Template file `2456566806586`, version `2724134783386`. Schema is Active in org.

### `HR_Check_DocGen_Status` (Active)

Path: `force-app/main/default/flows/HR_Check_DocGen_Status.flow-meta.xml`

- Input `recordId` (Case page) prefills the Case Id screen field.
- Calls `MyBox_GetCaseDocGenStatus`. Blank Apex `status` preserves prior `HR_Integration_Status__c`. Writes `Box_DocGen_Output_File_Id__c` only when present. Status-call failure → `DOCGEN_STATUS_UNAVAILABLE`, not `Doc Gen Failed`.
- Result shows Case number, status, and error code only.

### Flow authoring note

Salesforce Flow AI (`execute_metadata_action`) **cannot generate custom Apex Action elements**. Intake/status XML after the skeleton was authored and then edited in source (user-authorized). Prefer targeted XML edits over re-running the 3-step generate pipeline for Apex callouts. Long generate prompts also timed out.

## Apex (deployed)

API 66, Box package 5.56. Invocables have `callout=true` and `category='MyBox'`.

| Class | Role |
| --- | --- |
| `MyBox_DocGenFieldValue` | Flow DTO: `path`, `valueType`, `textValue`, `dateValue`, `numberValue`, `booleanValue` |
| `MyBox_DocGenSchemaService` | Generic load/validate/serialize. No New Hire branches. |
| `MyBox_SubmitTransientCaseDocGen` | Inputs: `caseId`, `boxFolderId`, `schemaKey`, `schemaVersion`, `fieldValues`. Outputs: `batchId`, `status`, `errorCode`. **No Case DML.** |
| `MyBox_GetCaseDocGenStatus` | Input: `caseId`. Outputs: `status`, `outputFileId`, `errorCode`. Resolves batch Id from Case. **No Case DML.** |
| `MyBox_DocGenBoxAdapter` / `Impl` | Test seam. `submitDocGenBatch` maps to `POST /2.0/docgen_batches`. `box.DocGenRequest` has no `input_source` property. |

Last org run: **33/33** tests, including the three submit paths that previously needed Active harness schema records. Coverage on submit/status/schema classes was in the 89–95% range; adapter impl is 0% (tests use the stub).

## Custom Metadata in org

Deploy via Metadata API still fails (`UNKNOWN_EXCEPTION`). Working workaround: `Metadata.Operations.enqueueDeployment` from anonymous Apex, small batches. `MasterLabel` max **40** characters (`NH1.0 {path}`, `H1.0 {path}`, …).

| Schema developer name | Key / version | Lifecycle in org |
| --- | --- | --- |
| `HR_DocGen_Schema.NewHire_1_0` | `newHire` / `1.0` | **Active** in org. File `2456566806586`, version `2724134783386` (activation job `0AfgK00000StKfZSAV`, 9 Sep 2026). |
| `HR_DocGen_Schema.MyBox_Test_Harness_1_0` | `myBoxTestHarness` / `1.0` | Active |
| `HR_DocGen_Schema.MyBox_Test_Harness_Tiny_1_0` | (tiny harness) | Active |
| `HR_DocGen_Schema.MyBox_Test_Harness_Collision_1_0` | (collision harness) | Active |

26 `NewHire_1_0_*` field records plus harness fields (37 field records total). `Box_Folder_Template_Id__c` on the schema type is unused by current Flows.

## Permissions

`MyBox_HR_DocGen_Access` grants Case FLS on the seven orchestration fields, Apex class access (`MyBox_SubmitTransientCaseDocGen`, `MyBox_GetCaseDocGenStatus`), Flow access for both intake/status Flows, Case create/read/edit (no view/modify all), and Run Flow. Assigned to admin John Koepp, user A, and user B. `box__Box_App_User` is assigned directly to A and B (not via a group).

## Org facts (stable)

| Item | Value |
| --- | --- |
| Username | `jkoepp+admin.5871147628f3@agentforce.com` |
| Org Id | `00DgK00000LNIJVUA5` |
| Instance | `https://orgfarm-d01c8c3fa9-dev-ed.develop.my.salesforce.com` |
| Box for Salesforce | 5.56.0.1 (`box`) |
| Experience site | Default Help Center, Live, `/portal` |
| Network Id | `0DBgK000001GudZWAS` |
| Case OWD | Internal ReadWriteTransfer; **external Private** |
| Case record types | `Portal_Request` only; HR intake uses **no** record type |
| Box root | `372250559857` (`Salesforce and AgenForce Root`) |
| Doc Gen template file | `2456566806586` (`new_hire_box_docgen.docx`), version `2724134783386` |
| User A | `005gK000074cosVQAQ` / `johnkoepp@gmail.com` / Customer Community Plus Login User |
| User B | `005gK00007dqzzXQAQ` / `riley.chen.hrdemo.b@example.test` / Customer Community Plus Login User |
| Toolkit SA (Box) | `49821057233` (`jkoepp+sfa@boxdemo.com`) |
| Intake page | `/portal/s/hr-request` |

## Outstanding org setup (blocks live demo, not further source work)

1. First Experience end-to-end run as user A, then user B isolation / substituted Id rejection.
2. If UI Elements fail to load: confirm Experience CCG app, CORS, and App User mapping (secrets not in source). Package CSP trusted sites `box__box*` are present; App User PS is assigned.
3. Confirm Help Center publish job `08PgK0000181a2vUAA` completed (email).

## Resume checklist

- Default org: `sf config get target-org` should be `agentforce-demo`.
- Do not retrieve/overwrite unrelated org metadata.
- Do not persist request-subject values on Case.
- CMDT record deploys: use Apex `Metadata.Operations.enqueueDeployment`, not `sf project deploy start --metadata CustomMetadata:...`.
- Privacy: synthetic data only.
