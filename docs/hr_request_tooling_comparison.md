# HR Request Tooling — Common vs Per-Form Artifacts

Comparison of the three intake options:

| Option | Source                                                             | Form UX                                              | Field contract                                          |
| ------ | ------------------------------------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------- |
| v1     | [hr_request_demo_tooling.md](hr_request_demo_tooling.md)           | One admin-built Screen Flow per schema               | `HR_DocGen_Field__mdt`, one row per path                |
| v2     | [hr_request_demo_tooling_v2.md](hr_request_demo_tooling_v2.md)     | One schema-driven LWC inside one generic Screen Flow | Versioned JSON file in Box                              |
| v3     | [hr_request_portal_tooling_v3.md](hr_request_portal_tooling_v3.md) | One admin-built multi-screen Flow per request type   | Same Box JSON as v2, used as a contract, not a renderer |

**Common** means built once and reused by every request type. **Per request type** means authored again for each form (a distinct screen graph or schema, such as New Hire/Rehire). A **schema version** (for example `newHire/1.0` to `newHire/1.1`) is called out separately because the three options treat that increment differently.

All three keep the same residency rule: Salesforce stores a generic Case and orchestration ids only. Box stores the generated PDF and supporting files. v2 and v3 also store the form contract in Box.

Folder creation in the as-built org is the shared action `box__CreateFolderForRecordId_v2` (folder name = Case number). The v1 plan text still mentions a per-schema folder template; do not build folder templates for new forms.

## Side-by-side

| Work                                       | v1                                                      | v2                                                 | v3                                               |
| ------------------------------------------ | ------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------------ |
| Apex submit and status                     | Once                                                    | Once (loader reads Box JSON)                       | Once (same loader as v2 if it exists)            |
| Case orchestration fields                  | Once (seven fields)                                     | Once                                               | Once                                             |
| Status Flow `HR_Check_DocGen_Status`       | Once                                                    | Once                                               | Once                                             |
| Home navigation `c:hrNavigateToPortalHome` | Once                                                    | Once                                               | Once                                             |
| Intake Screen Flow                         | One Flow per schema, including a copy for a new version | One Flow for every request type                    | One Flow per request type                        |
| Form LWC                                   | None                                                    | One LWC for every request type                     | None                                             |
| Field definitions                          | One Custom Metadata row per path                        | Paths live in that form's Box JSON                 | Paths live in that form's Box JSON               |
| Schema pointer row                         | One fat row per version (template ids on the row)       | One thin row per version                           | One thin row per version                         |
| Box Doc Gen template                       | One per version                                         | One per version                                    | One per version                                  |
| Add a field to an existing form            | Edit the Flow, add a field row, retag the template      | Publish JSON and a template. No Flow or LWC edit   | Edit the Flow, publish JSON, retag the template  |
| Add a request type                         | Copy the Flow; new field rows, pointer, and template    | New JSON, pointer, and template. Same Flow and LWC | New Flow, JSON, pointer, and template. Same Apex |

## v1 — Screen Flow and field Custom Metadata

Source: [hr_request_demo_tooling.md](hr_request_demo_tooling.md). This is the as-built New Hire path (`HR_New_Hire_Intake`, `newHire/1.0`).

### Common to every request type

| Artifact                                                             | Where                 | Role                                                                                                                                                                                                                   |
| -------------------------------------------------------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MyBox_DocGenFieldValue`                                             | Apex                  | Typed descriptor (`path`, `valueType`, one of text/date/number/boolean). Every Flow fills a list of these.                                                                                                             |
| `MyBox_DocGenSchemaService`                                          | Apex                  | Loads `HR_DocGen_Schema__mdt` and `HR_DocGen_Field__mdt`, validates, serializes `user_input`. No request-type branches.                                                                                                |
| `MyBox_SubmitTransientCaseDocGen`                                    | Apex invocable        | Case/folder checks, then `box.DocGenToolkit.submitDocGenBatch`. Returns batch id, status, error code. No Case DML.                                                                                                     |
| `MyBox_GetCaseDocGenStatus`                                          | Apex invocable        | Normalizes `GET /2.0/docgen_batch_jobs/{batch_id}`. No Case DML.                                                                                                                                                       |
| `MyBox_DocGenBoxAdapter` / `Impl`, `MyBox_DocGenValidationException` | Apex                  | Package-call test seam and sanitized error codes.                                                                                                                                                                      |
| `HR_DocGen_Schema__mdt` type                                         | Custom Metadata       | Schema-version definition: key, version, lifecycle, template file/version ids, output type, filename pattern, payload cap.                                                                                             |
| `HR_DocGen_Field__mdt` type                                          | Custom Metadata       | Field-rule definition: path, type, required, max length, blank behavior, allowed values. The type is shared; the rows are not.                                                                                         |
| Seven Case fields                                                    | Case                  | `HR_Request_Schema_Key__c`, `HR_Request_Schema_Version__c`, `HR_Integration_Status__c`, `HR_Intake_Managed_Provisioning__c`, `Box_DocGen_Batch_Id__c`, `Box_DocGen_Output_File_Id__c`, `HR_Integration_Error_Code__c`. |
| `MyBox_HR_DocGen_Access`                                             | Permission set        | FLS on the seven Case fields, plus Flow/Apex access for Experience users.                                                                                                                                              |
| `HR_Check_DocGen_Status`                                             | Screen Flow           | Manual status refresh from the Case page. Input is Case id only.                                                                                                                                                       |
| `c:hrNavigateToPortalHome`                                           | Aura local action     | Finish returns to Experience `/s/` home.                                                                                                                                                                               |
| `Create_Box_Folder_for_New_Case` exclusion                           | Record-triggered Flow | Skip Cases with `HR_Intake_Managed_Provisioning__c = true` so intake does not double-provision.                                                                                                                        |
| Case-page Content Explorer                                           | Experience page       | Preview, upload, download. Delete, rename, share, and folder create stay off.                                                                                                                                          |
| Box service account, Doc Gen entitlement, App User                   | Box / org setup       | Shared runtime identity. Experience users do not browse template or root folders.                                                                                                                                      |

### Built for each request type or form

| Artifact                                             | New request type                                                                 | New version of the same form (for example `1.1`)                     | Role                                                                           |
| ---------------------------------------------------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Intake Screen Flow                                   | New Flow (copy of the pattern, not a shared Flow)                                | New Flow copy (`HR_New_Hire_Intake_Schema_Demo` for the `1.1` proof) | Screens, choice lists, visibility, conditional requiredness, attestation.      |
| Screen components and formulas                       | Full set for that form                                                           | The added field plus its visibility rule                             | Standard Text, Email, Date, Checkbox, Picklist, Text Area.                     |
| Assignment elements and `fv...` resources            | One descriptor resource and one assignment row per path                          | One new `fv...` resource and assignment                              | Copies screen values into `colDocGenFields` after the folder id exists.        |
| Flow constants                                       | `cSchemaKey`, `cSchemaVersion`, and any constant paths such as notification type | New version constant                                                 | Selectors are Flow metadata, not user input.                                   |
| `HR_DocGen_Schema__mdt` record                       | One row, including that form's template file and version ids                     | One new row (`newHire` / `1.1`)                                      | Active lifecycle, output filename pattern, payload cap.                        |
| `HR_DocGen_Field__mdt` records                       | One row per JSON path (26 for `newHire/1.0`)                                     | One new row for the added path; prior rows stay                      | Allow-list Apex validates against. Conditional requiredness stays in the Flow. |
| Box Doc Gen Word template                            | One template, tags for every path plus `schema` and `case`                       | New template version with the extra tag                              | Pinned by file id and file-version id on the schema row.                       |
| Template manifest and synthetic `user_input` example | One manifest section and one example JSON                                        | Updated example that includes the new path                           | Authoring and smoke-test inputs. Not stored as live request data.              |
| Experience launcher                                  | Page or navigation item that starts that Flow                                    | Second labeled launcher so both versions can run                     | v1 does not use a catalog screen.                                              |
| Field contract checklist                             | One checklist (labels, choices, requiredness, conditions)                        | Delta for the new path                                               | `docs/hr_request_demo_contract.md` is the `newHire/1.0` instance.              |

## v2 — Schema-driven LWC and Box JSON

Source: [hr_request_demo_tooling_v2.md](hr_request_demo_tooling_v2.md). One generic Flow hosts `c:hrIntakeForm`. A new request type does not copy the Flow or the LWC.

### Common to every request type

| Artifact                                                                           | Where                         | Role                                                                                                                                                                         |
| ---------------------------------------------------------------------------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MyBox_DocGenFieldValue`                                                           | Apex                          | Unchanged DTO. The LWC emits `List<MyBox_DocGenFieldValue>`.                                                                                                                 |
| `MyBox_SubmitTransientCaseDocGen`                                                  | Apex invocable                | Same inputs and outputs. Internally validates against the parsed Box schema and the `docGen` template ids. Two callouts (schema GET, then Doc Gen POST) and no Case DML.     |
| `MyBox_GetCaseDocGenStatus` and `HR_Check_DocGen_Status`                           | Apex + Flow                   | Unchanged.                                                                                                                                                                   |
| `MyBox_DocGenSchemaService` (refactored)                                           | Apex                          | Load the thin pointer, GET and meta-validate Box JSON, honor `requiredWhen`, omit hidden paths, serialize. Stops reading `HR_DocGen_Field__mdt` on this path.                |
| Box content adapter                                                                | Apex                          | `GET /2.0/files/{file_id}/content?version=` via `box.Toolkit.sendRequest`. Test stub, same idea as `MyBox_DocGenBoxAdapter`.                                                 |
| `getFormContract`                                                                  | `@AuraEnabled` Apex           | Returns sections and user-visible fields. Strips template file and version ids. Non-cacheable.                                                                               |
| Rule DSL evaluator                                                                 | Apex and LWC                  | Closed operators: `equals`, `notEquals`, `in`, `isTrue`, `isFilled`, `and`, `or`.                                                                                            |
| Narrowed `HR_DocGen_Schema__mdt` type                                              | Custom Metadata               | Pointer only: key, version, request-type label, lifecycle, Box schema file id, pinned file-version id, optional catalog sequence. No field-list type on this path.           |
| Seven Case fields, `MyBox_HR_DocGen_Access`                                        | Case + permission set         | Same orchestration fields. Add class access for `getFormContract` and the content adapter.                                                                                   |
| `c:hrIntakeForm`                                                                   | LWC (`lightning__FlowScreen`) | Closed widget catalog (`text`, `email`, `number`, `date`, `checkbox`, `textarea`, `picklist`). Loops sections from the contract. Jest uses a fixture JSON, not org metadata. |
| `HR_Request_Intake`                                                                | One Screen Flow               | Catalog of Active pointers, one form screen hosting the LWC, Case create, folder create, submit, clear collection, uploader, receipt, Home navigation.                       |
| Box schema config folder                                                           | Box                           | Service-account read. Experience users have no collaboration. Not a Case folder.                                                                                             |
| `c:hrNavigateToPortalHome`, folder exclusion, Case-page Explorer, uploader element | Experience / Flow             | Same shared shell as v1. Uploader sits on the generic Flow's receipt screen.                                                                                                 |

Redeploy the LWC and extend the Apex `uiControl` allow-list only when a form needs a widget the catalog does not have. That is a platform change, not a per-form artifact.

### Built for each request type or form

| Artifact                  | New request type                                                  | New version of the same form (for example `1.1`)                     | Role                                                                                                                                                               |
| ------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Box schema JSON           | New file: `schema`, `docGen`, `sections`, `fields`, rules         | New file or new file version with the added path                     | Canonical contract. Labels, controls, `required` / `requiredWhen` / `visibleWhen`, `allowedValues`, `inputSource`, template pin, payload cap. No submitted values. |
| Git example of that JSON  | `docs/examples/` copy for review                                  | Updated example                                                      | Review copy. Box remains canonical.                                                                                                                                |
| Thin pointer row          | One Active `HR_DocGen_Schema__mdt` row                            | One new row (or a repointed file version) for `key` / `1.1`          | Pins the Box file version. Key and version must match the JSON.                                                                                                    |
| Box Doc Gen Word template | One template; file and version ids go in `docGen` inside the JSON | Template version with the new tag                                    | Not stored on the Salesforce pointer.                                                                                                                              |
| Catalog label             | `Request_Type__c` on that pointer row                             | New label only if the version should appear as its own catalog entry | The generic Flow lists Active rows. No second Flow.                                                                                                                |

No per-form Screen Flow, Assignment list, field Custom Metadata rows, or LWC change. An Experience URL may preselect `schemaKey` and `schemaVersion`; that is a parameter on the shared launcher.

## v3 — Manual multi-screen Flow and Box JSON

Source: [hr_request_portal_tooling_v3.md](hr_request_portal_tooling_v3.md). Use this when the next screen, a skipped step, or a branch-specific page depends on earlier answers. The Box JSON is the payload contract. It does not render the wizard.

### Common to every request type

| Artifact                                                        | Where                 | Role                                                                                                                                                                                                                                        |
| --------------------------------------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MyBox_DocGenFieldValue`                                        | Apex                  | Assignment target. Same shape as v1 and v2.                                                                                                                                                                                                 |
| `MyBox_DocGenSchemaService`                                     | Apex                  | If the v2 loader exists, call it. Load the thin pointer, GET and meta-validate Box JSON, enforce `required` and `requiredWhen`, drop values whose `visibleWhen` is false, inject `inputSource` `server` and `constant`, build `user_input`. |
| `MyBox_SubmitTransientCaseDocGen`                               | Apex invocable        | Same signature. Schema GET then Doc Gen POST. No Case DML. No New Hire branches.                                                                                                                                                            |
| `MyBox_GetCaseDocGenStatus` and `HR_Check_DocGen_Status`        | Apex + Flow           | Unchanged.                                                                                                                                                                                                                                  |
| Thin `HR_DocGen_Schema__mdt` pointer type                       | Custom Metadata       | Same fields as v2. No `HR_DocGen_Field__mdt` on this path.                                                                                                                                                                                  |
| Box content adapter and schema config folder                    | Apex + Box            | Same GET and the same non-browsable config folder as v2.                                                                                                                                                                                    |
| Seven Case fields and `MyBox_HR_DocGen_Access`                  | Case + permission set | Same orchestration backbone.                                                                                                                                                                                                                |
| `box__CreateFolderForRecordId_v2` and the intake exclusion      | Flow action           | Shared. Folder id stays in `vBoxFolderId`.                                                                                                                                                                                                  |
| `c:hrNavigateToPortalHome`, receipt pattern, Case-page Explorer | Experience / Flow     | Each wizard's Finish uses the same Home action. Explorer is on the shared Case page.                                                                                                                                                        |

v3 does not build `c:hrIntakeForm` or `getFormContract`. The Flow does not download the schema to draw itself.

### Built for each request type or form

| Artifact                                  | New request type                                                      | New version of the same form (for example `1.1`)                              | Role                                                                                                                                                                                                                 |
| ----------------------------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Intake Screen Flow                        | New Flow for that wizard                                              | Edit the existing wizard (this option does not copy the Flow for a field add) | Screens, Decisions, skipped steps, branch pages, component visibility.                                                                                                                                               |
| Screen components                         | Full set for that wizard                                              | The new component on the screen where it belongs                              | Standard Flow inputs, plus a dynamic record choice when the list is non-PII reference data.                                                                                                                          |
| Assignment elements and `fv...` resources | One per path, grouped by section (`Build_Employee_Fields`, and so on) | One new assignment                                                            | The only binding from a screen component to a JSON path. Apex cannot discover screen outputs by API name.                                                                                                            |
| Stale-value variables                     | One per field whose branch can hide it                                | One if the new field is conditional                                           | Copy the screen value, blank the variable when the branch does not apply, map the variable. Hiding a component does not clear it.                                                                                    |
| Flow constants                            | `cSchemaKey` and `cSchemaVersion` for that wizard                     | Version constant if this Flow should submit the new version                   | Server and constant paths (`request.requestDate`, notification type) are injected by Apex from the JSON. The Flow does not collect them.                                                                             |
| Box schema JSON                           | New file, same shape as v2                                            | Updated file or file version                                                  | Enforced at submit: path, type, required, `requiredWhen`, `visibleWhen`, allowed values, blank behavior, `inputSource`. `sections` and `uiControl` may be present for a shared file with v2; a v3 Flow ignores them. |
| Thin pointer row                          | One Active row pinning that file version                              | New row or new pinned version                                                 | Same pointer as v2.                                                                                                                                                                                                  |
| Box Doc Gen Word template                 | One template; ids live under `docGen` in the JSON                     | Template version with the new tag                                             | Submit fails closed on an unknown path or a missing required path.                                                                                                                                                   |
| Experience launcher                       | Navigation or page that starts this Flow                              | Reuse the same launcher if the Flow api name does not change                  | One entry per wizard, not a generated catalog.                                                                                                                                                                       |

A rule that only chooses the next page stays in the Flow. A rule Apex must enforce even if the Flow emits the value goes in the JSON DSL.

## What stays out of all three

These are not form artifacts and are not part of the per-request-type cost:

- OmniStudio, Dynamic Forms, Surveys, or Field Service Data Capture (they persist answers on Salesforce records).
- A custom object for the request payload.
- Pause, Wait, save-for-later, schedulers, webhooks, or a resume-from-failed-Case UI.
- Repeatable row groups.
- v2 phase 2 (an LWC that never hands field values to Flow).
