# HR Request Demo — Current State

Handoff as of **8 Sep 2026**. Target org alias: **`agentforce-demo`**. Do not use `box-sandbox` or `mia-sandbox`.

Read this first when resuming. Then [hr_request_demo_environment.md](hr_request_demo_environment.md) for org IDs and [hr_request_demo_contract.md](hr_request_demo_contract.md) for the frozen `newHire/1.0` field map. The original plan remains [hr_request_demo_tooling.md](hr_request_demo_tooling.md); folder creation has since been simplified (see below).

Synthetic HR data only. Never persist form PII on Case, Files, notes, logs, error emails, or CMDT.

## Chunk status

| Chunk | Goal | Status |
| --- | --- | --- |
| 0 | Environment handoff | **Done** in source. Several org setup items still outstanding (users, permissions, Doc Gen JSON API, Experience Box App User). |
| 1 | Contract + CMDT | **Done.** Checklist frozen. Types, 26 `newHire/1.0` fields, harness fields, and 4 schema records are in the org. `NewHire_1_0` stays **Draft** (no Box template IDs). |
| 2 | Box Doc Gen Word template | **Not started.** Blocks a live PDF. |
| 3 | Generic Apex submit/status | **Done** and deployed. Tests passing in org. |
| 4 | `HR_New_Hire_Intake` | **Draft Flow in repo and org.** Full form + mapping + folder + submit + faults. Not activated. |
| 5 | `HR_Check_DocGen_Status` | **Draft Flow in repo and org.** Apex status call + Case DML. Not activated. |
| 6 | Experience page, permissions, first live run | **Not started.** Do not activate intake until competing folder Flow excludes intake Cases. |
| 7 | `newHire/1.1` + schema-demo Flow copy | **Not started.** |
| 8 | Presenter runbook | **Not started.** |

## What to do next

1. **Chunk 2** — Author a JSON Doc Gen template for all 26 paths plus `schema.key`, `schema.version`, `case.id`, `case.caseNumber`. Confirm the Toolkit **service account** can call the Doc Gen batch API (CLI actor previously got HTTP 404 on `GET /2.0/docgen_templates`). Write `docs/hr_request_demo_template_manifest.md` with file/version IDs. Do not activate `HR_DocGen_Schema.NewHire_1_0` until chunk 6.
2. **Chunk 6** — Add `HR_Intake_Managed_Provisioning__c != true` to `Create_Box_Folder_for_New_Case` (keep the blank-record-type filter). Create Experience user B. Assign Apex class access, Flow access, Case create/read, and Box App User rights to users A and B. Put the intake Flow on Default Help Center (`/portal`). Activate intake only after the exclusion is live. First end-to-end run with synthetic data.
3. **Chunks 7–8** — `newHire/1.1` (`request.referenceNote`), Flow copy `HR_New_Hire_Intake_Schema_Demo`, runbook.

## Folder creation (implementation change)

Plan text still mentions `box__CreateFolderForRecordIdFromTemplate_v2`. **Do not go back to templates.**

Both Flows now call **`box__CreateFolderForRecordId_v2`** (Create Folder For Record ID):

| Flow | Status in org | Behavior |
| --- | --- | --- |
| `Create_Box_Folder_for_New_Case` | **Active** | Case create, RecordTypeId blank/null, async after commit. Folder name = Case number. `optCreateRootFolder = true`. No template, no Case Type parent, no `sfCaseRecord` metadata cascade. |
| `HR_New_Hire_Intake` | **Draft** | After Case create, **new transaction**, same action, folder name = Case number. Folder Id stays in `vBoxFolderId` only (not a Case field). |

Intake Cases still match the Active record-triggered Flow. Exclude them in chunk 6 before activating intake. If both run, the Toolkit should reuse the record–folder association rather than cloning a template tree.

## Flows

### `HR_New_Hire_Intake` (Draft)

Path: `force-app/main/default/flows/HR_New_Hire_Intake.flow-meta.xml`

- One screen, sections: Employee, Assignment, Certification, Compensation, Notes, Submitter.
- All 26 contract paths assigned into `colDocGenFields` (`MyBox_DocGenFieldValue`). Constants `cSchemaKey=newHire`, `cSchemaVersion=1.0`, `cNotificationType=newHireRehire`. `request.requestDate` = `$Flow.CurrentDate`.
- Rate reason visible/required only for `Above minimum` / `Above maximum`; otherwise cleared before Case create.
- Case shell: Subject `HR Request`, Origin `Web`, no Description/PII, `HR_Intake_Managed_Provisioning__c=true`, schema pointers, status `Case Created`.
- Submit: `MyBox_SubmitTransientCaseDocGen` in a **new transaction**. Flow writes batch Id / status / error code.
- Faults: folder → `Folder Failed`; submit fail → `Doc Gen Submit Failed`; unknown → `Submission Unknown`; Case update fail → `CASE_UPDATE_FAILED`. Never copy `$Flow.FaultMessage`.
- Receipt: Case number + integration status only; Previous disabled; `box:UIElementUpload` with `folderId={!vBoxFolderId}`. Collection cleared first.

Live submit will return `SCHEMA_UNKNOWN_OR_INACTIVE` until `NewHire_1_0` is **Active** with Box template file/version IDs.

### `HR_Check_DocGen_Status` (Draft)

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
| `MyBox_DocGenBoxAdapter` / `Impl` | Test seam. `box.DocGenRequest` has no `input_source` property. |

Last org run: **33/33** tests, including the three submit paths that previously needed Active harness schema records. Coverage on submit/status/schema classes was in the 89–95% range; adapter impl is 0% (tests use the stub).

## Custom Metadata in org

Deploy via Metadata API still fails (`UNKNOWN_EXCEPTION`). Working workaround: `Metadata.Operations.enqueueDeployment` from anonymous Apex, small batches. `MasterLabel` max **40** characters (`NH1.0 {path}`, `H1.0 {path}`, …).

| Schema developer name | Key / version | Lifecycle in org |
| --- | --- | --- |
| `HR_DocGen_Schema.NewHire_1_0` | `newHire` / `1.0` | **Draft** |
| `HR_DocGen_Schema.MyBox_Test_Harness_1_0` | `myBoxTestHarness` / `1.0` | Active |
| `HR_DocGen_Schema.MyBox_Test_Harness_Tiny_1_0` | (tiny harness) | Active |
| `HR_DocGen_Schema.MyBox_Test_Harness_Collision_1_0` | (collision harness) | Active |

26 `NewHire_1_0_*` field records plus harness fields (37 field records total). `Box_Folder_Template_Id__c` on the schema type is unused by current Flows.

## Permissions

`MyBox_HR_DocGen_Access` is **Case FLS only** (seven orchestration fields). Assigned to admin John Koepp. Still needed for Experience users A/B in chunk 6:

- Apex class access: `MyBox_SubmitTransientCaseDocGen`, `MyBox_GetCaseDocGenStatus`
- Flow access for both Draft Flows
- Case Create and Read
- Box App User (Experience Cloud) permission set (assign directly, not via a group)

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
| User A | `005gK000074cosVQAQ` / `johnkoepp@gmail.com` / Customer Community Plus Login User |
| User B | **Does not exist** |

## Outstanding org setup (blocks live demo, not further source work)

1. User B (Community Plus or equivalent, Default Help Center member, same least-privilege as A).
2. Permission assignment for A/B (see above).
3. Doc Gen JSON/batch API for the Toolkit **service account**, write access under the Box root.
4. Experience Cloud Box UI Elements (Client Credentials Grant app, CORS, App User mapping) on Default Help Center.
5. Chunk 6 exclusion on `Create_Box_Folder_for_New_Case` before activating intake.

## Resume checklist

- Default org: `sf config get target-org` should be `agentforce-demo`.
- Do not retrieve/overwrite unrelated org metadata.
- Do not activate `HR_New_Hire_Intake` or `HR_Check_DocGen_Status` until chunk 6 exclusion and permissions are in place.
- Do not persist request-subject values on Case.
- CMDT record deploys: use Apex `Metadata.Operations.enqueueDeployment`, not `sf project deploy start --metadata CustomMetadata:...`.
- Privacy: synthetic data only.
