# HR Request Demo — Chunk 6 Integration Results

Recorded **9 Sep 2026**. Target org alias: **`agentforce-demo`**. Synthetic data only. No request payloads, tokens, or raw Box error bodies.

## Toolkit service-account Doc Gen

Acting identity for Toolkit callouts (via `box.Toolkit.sendRequest` / `box.DocGenToolkit.submitDocGenBatch`):

| Item | Value |
| --- | --- |
| JWT config | `BoxJWTConfig__mdt.Default_Config` |
| Box user | `49821057233` (`Salesforce AgentForce User`, `jkoepp+sfa@boxdemo.com`) |
| Configured root | `372250559857` |
| Template file GET | HTTP 200 for `2456566806586` / version `2724134783386` |
| `GET /2.0/docgen_templates` | HTTP 200 as this service account (`box-version: 2025.0`) |
| Smoke destination folder | `416641835701` (`HR_DocGen_SA_Smoke_20260909`) |
| `submitDocGenBatch` batch Id | `dfadffe5-250e-43d9-a0ab-beb8dcbb5f5b` |
| Batch job | `completed`; output file `2456627065285` |

CLI OAuth user `35570754363` is a different actor and is not this proof.

## Folder-Flow exclusion

`Create_Box_Folder_for_New_Case` entry criteria are now `(RecordTypeId blank OR null) AND HR_Intake_Managed_Provisioning__c != true`. Active in org.

## Experience users and permissions

| Role | User Id | Username | Account | Notes |
| --- | --- | --- | --- | --- |
| User A | `005gK000074cosVQAQ` | `johnkoepp@gmail.com` | `001gK00001NjLtlQAF` (Test Account) | Default Help Center member. `MyBox_HR_DocGen_Access` + `box__Box_App_User`. |
| User B | `005gK00007dqzzXQAQ` | `riley.chen.hrdemo.b@example.test` | `001gK00001STqVdQAL` (HR Demo Isolation B) | Separate Account for Case isolation. Same permission sets. Network member `0DBgK000001GudZWAS`. |

`MyBox_HR_DocGen_Access` now includes Apex class access, Flow access, Case create/read/edit (no view/modify all), and Run Flow, in addition to the seven orchestration field FLS grants.

## Site wiring

Default Help Center (`/portal`, LWR bundle `Default_Help_Center1` at `/portal/s`):

- Page `/hr-request` embeds `HR_New_Hire_Intake`.
- Default Navigation: Home, HR Request (authenticated).
- Case Detail embeds `HR_Check_DocGen_Status` then existing `Portal_User_Box_Folder_Component`.
- Explorer flags on that Flow: preview/upload/download on; delete/rename/share/folder-create off.

Site publish job `08PgK0000181a2vUAA` was started 9 Sep 2026. Confirm the publish email before the presenter run.

Intake URL: `https://orgfarm-d01c8c3fa9-dev-ed.develop.my.site.com/portal/s/hr-request`

## Schema and Flows

| Artifact | Org state |
| --- | --- |
| `HR_DocGen_Schema.NewHire_1_0` | **Active**. File `2456566806586`, version `2724134783386`. |
| `HR_New_Hire_Intake` | **Active** |
| `HR_Check_DocGen_Status` | **Active** |

Intake activation required XML fixes: boolean screen fields must be required; rate-reason clear cannot assign a screen component; uploader visibility uses formula `fHasBoxFolderId`; status formula wraps `HR_Integration_Status__c` with `TEXT()`.

## Box UI Elements configuration observed

- Package CSP trusted sites present: `box__box`, `box__boxWild`, `box__boxCloud`, `box__boxCloudStar`.
- Box App User (Experience Cloud) assigned directly to A and B.
- JWT/service-account Doc Gen and folder-create path proved above.

Client Credentials Grant app settings and CORS allow-list contents were not exported (managed/secret configuration). Confirm in Box Admin / Box for Salesforce setup if UI Elements fail to load in the site.

## Not yet run

- Authenticated Experience submission as user A (synthetic form, PDF, supporting upload, status refresh).
- User B isolation (cannot see A's Case/folder).
- Substituted folder/Case Id rejection as Experience user.
