# HR Request Intake v2 — Schema-driven Form and Box-hosted Contract

## Relationship to v1

[hr_request_demo_tooling.md](hr_request_demo_tooling.md) is the **as-built v1 plan**. That design is implemented, deployed, and working in `agentforce-demo`: a New Hire/Rehire Screen Flow, `HR_DocGen_Field__mdt` rows, and schema-neutral `MyBox_SubmitTransientCaseDocGen`. Current org state: [hr_request_demo_status.md](hr_request_demo_status.md). Frozen field map: [hr_request_demo_contract.md](hr_request_demo_contract.md).

This v2 document is the **next architecture**, not a rewrite of Box Doc Gen, Case residency, or the submit/status Apex contracts. v1 remains Active until the v2 path is proven on the Experience site. Do not deactivate `HR_New_Hire_Intake` as part of authoring this design.

v1 proved:

- Transient JSON Doc Gen through `box.DocGenToolkit.submitDocGenBatch` (`POST /2.0/docgen_batches`) with no request PII on Case.
- One generic validator/serializer with no New Hire branches.
- Folder create via `box__CreateFolderForRecordId_v2` (not a folder template), Box uploader/explorer, and manual status refresh.

v1 does not scale because **the form UX is still per-schema**. Chunk 7 would copy the entire Flow for `newHire/1.1`. Custom Metadata field rows are hard to maintain (one record per path, 40-character labels, Metadata API `UNKNOWN_EXCEPTION` on CMDT records in this org). Visibility and conditional requiredness live in Flow, so Apex cannot enforce the real rate-reason rule.

v2 moves the **field/UI contract** to a versioned JSON file in Box and renders it with one schema-driven LWC inside one generic Screen Flow.

## Summary

Authenticated Experience Cloud intake still:

1. Collects request data transiently (synthetic HR data only).
2. Creates a non-sensitive Case shell.
3. Creates the Case Box folder (`box__CreateFolderForRecordId_v2`, folder name = Case number).
4. Submits an in-memory JSON payload to Box Doc Gen.
5. Presents the Box uploader and a generic receipt, then navigates Home via `c:hrNavigateToPortalHome`.

Salesforce must still not persist request-subject PII. Box remains the system of record for the generated PDF, supporting files, **and now the form/validation schema**.

What changes:

| Concern           | v1                                                     | v2                                                                                                                              |
| ----------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| Form UI           | Standard Screen Flow components, one Flow per schema   | One Flow-screen LWC loops a schema and renders a closed widget catalog                                                          |
| Field contract    | `HR_DocGen_Field__mdt` (26+ rows per version)          | One versioned JSON file in Box                                                                                                  |
| Schema pointer    | CMDT key/version plus template IDs and every field row | Thin Salesforce pointer: key, version, lifecycle, Box schema file id, pinned file version id                                    |
| Template IDs      | On `HR_DocGen_Schema__mdt`                             | Inside the Box schema JSON (`docGen`), pinned with that file version                                                            |
| Conditional rules | Flow Decisions / component visibility                  | Tiny JSON rule DSL in the schema; LWC for UX, Apex for enforcement                                                              |
| Schema extension  | Copy Flow (`HR_New_Hire_Intake_Schema_Demo`)           | New Box JSON (or file version) + template + one pointer row. No Flow copy. Unchanged Apex/LWC unless a new `uiControl` is added |
| OmniStudio        | Not used                                               | Not used. See [OmniScript is not required](#omniscript-is-not-required)                                                         |

Reuse without change of meaning: `MyBox_DocGenFieldValue`, `MyBox_SubmitTransientCaseDocGen` invocable inputs/outputs, `MyBox_GetCaseDocGenStatus`, seven Case orchestration fields, `HR_Check_DocGen_Status`, Box UI Elements, PII boundary.

## Demo scope and acceptance

Keep the specified New Hire/Rehire form (all mapped fields, attestation, rate-reason condition) and the `newHire/1.1` optional-field proof. “Flexible schema” now means: add an approved field or schema version by publishing Box JSON and a template, without changing Apex or the form LWC, and without a second Flow.

The v2 demo is complete when:

1. An authenticated Experience user submits the full `newHire/1.0` form from the **generic** intake Flow / schema-driven LWC using synthetic HR data.
2. One generic Case and managed Box folder are created; the PDF contains the mapped values (same Doc Gen path as v1).
3. The user uploads a synthetic supporting file to Box and can preview.
4. Manual **Check document status** still works (`HR_Check_DocGen_Status` unchanged).
5. `newHire/1.1` adds `request.referenceNote`, renders it, and generates with an updated template. **No Flow copy. No Apex source change.** `1.0` remains intact and rejects the extra path.
6. Storage-boundary and access checks still hold. Schema JSON in Box contains no submitted values and no sample PII.

Supporting uploads stay optional for completion. “Send me a copy of my responses” stays out of scope.

### Deferred

Scheduled polling, webhooks, completion notifications, automated schema release gates, a general expression language, repeatable/nested array fields (`certifications[].n`), i18n of schema labels, Platform Cache of schema JSON, failed-Case resume, and **phase 2** (LWC-owned Case/folder/submit so values never enter Flow). Phase 1 accepts the same Flow-interview privacy model as v1.

### Documented capabilities (unchanged)

Apex-defined Flow types, `MyBox_DocGenFieldValue` shape, and Box Doc Gen `POST /2.0/docgen_batches` / `GET /2.0/docgen_batch_jobs/{batch_id}` are established. See [hr_request_demo_tooling.md](hr_request_demo_tooling.md) for the request body, `box.DocGenRequest` property list (`input_source` is not an Apex property), and [examples/newHire_1_0_user_input.json](examples/newHire_1_0_user_input.json). Template IDs: [hr_request_demo_template_manifest.md](hr_request_demo_template_manifest.md) (`2456566806586` / `2724134783386`).

v2 adds Box Content API file download, already used in this org via `box.Toolkit.sendRequest` ([`MyBox_CopyFile`](../force-app/main/default/classes/MyBox_CopyFile.cls)):

| Operation               | REST                                                                                                                            | Runtime                                                                                                   |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Read pinned schema JSON | [`GET /2.0/files/{file_id}/content`](https://developer.box.com/reference/get-files-id-content) with `version={file_version_id}` | `box.Toolkit.sendRequest`. **Do not** send `box-version: 2025.0` on this GET; that header is Doc Gen only |

## Data residency and persistence boundary

v1 rules still apply. Synthetic data only. No request-subject PII on Case, Files, Notes, Tasks, events, async jobs, debug logs, error emails, or Custom Metadata.

**Schema JSON is configuration, not a request.** It may live in Box and may be copied to git as an example. It must not contain submitted values, secrets, access tokens, or live-looking sample PII. Synthetic `user_input` examples stay in git ([examples/newHire_1_0_user_input.json](examples/newHire_1_0_user_input.json)), not in the live schema file.

Platform Cache remains forbidden for **payload**. An optional later cache of schema JSON keyed by Box file version id is configuration-only and is **not** in the first v2 slice.

Phase 1 still holds form values in LWC memory, then in the Flow `colDocGenFields` collection, then on the Apex heap, then in the Box Doc Gen request. Clear the collection after submit. Failed Flow interviews can still capture variable state; do not claim guaranteed erasure. Phase 2 (private LWC orchestration) is documented below and is out of the first build.

### Permitted in Salesforce (v2 additions)

- Thin schema pointer records (key, version, lifecycle, opaque Box schema file/version ids). No field list.
- Case schema key/version (audit pointer only; cannot reconstruct the request).

### Permitted in Box (v2 additions)

- Versioned schema JSON in a **config folder** the Toolkit service account can read and Experience users cannot browse.
- Existing: Doc Gen templates, Case folders, generated PDFs, supporting uploads.

## Rejected alternatives

| Option                                                  | Why not                                                                                                                                              |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Another Screen Flow per schema                          | v1 scaling failure. Form labels, picklists, visibility, and Assignments are the per-schema cost.                                                     |
| Salesforce Dynamic Forms / `lightning-record-edit-form` | Requires sObject fields. Would persist PII.                                                                                                          |
| Surveys / Assessment Questions                          | Stores responses in Salesforce.                                                                                                                      |
| Flow Repeater with a few generic inputs                 | Still statically authored; cannot add a path without editing Flow.                                                                                   |
| CI-generated Flow XML from metadata                     | Still N deployed Flows; Flow XML is already fragile in this repo.                                                                                    |
| OmniStudio OmniScript / DataRaptors                     | Licensed product, not installed here, usually persists via DataRaptors, and would store the form definition in Salesforce metadata again. See below. |
| Long Text JSON on one CMDT record                       | Simpler runtime (no GET) but canonical store would remain Salesforce metadata. Operators chose Box as canonical.                                     |
| LWC or Flow building the Doc Gen JSON string            | Loses type fidelity. Keep typed descriptors; Apex `JSON.serialize` only.                                                                             |
| `lwc:component` dynamic constructors                    | Unnecessary for a small closed catalog; weaker Experience/Flow story. Use `lwc:if` on `uiControl`.                                                   |

## OmniScript is not required

OmniScript is Salesforce’s packaged guided-interview designer. It is **not** a dependency. v2’s form renderer is a custom LWC with a closed widget catalog.

Not using OmniScript means: no OmniStudio license or runtime, no DataRaptor save of answers, no second orchestration stack, and schema truth stays in Box. The cost is owning `hrIntakeForm` (controls, visibility, conditional required, stale-value clearing). Repeatable groups and a vendor designer are out of v1/v2 slice 1.

## Architecture

```mermaid
sequenceDiagram
  actor User
  participant Flow as HR_Request_Intake
  participant LWC as hrIntakeForm
  participant ApexUI as getFormContract
  participant SF as PointerAndCase
  participant ApexSub as SubmitTransientCaseDocGen
  participant Toolkit as BoxToolkit
  participant Box as BoxContentAndDocGen

  User->>Flow: Open intake
  Flow->>LWC: schemaKey schemaVersion or catalog
  LWC->>ApexUI: imperative getFormContract
  ApexUI->>SF: Active pointer
  ApexUI->>Toolkit: GET files/id/content pinned version
  Toolkit->>Box: Schema JSON
  ApexUI-->>LWC: UI contract no template IDs
  User->>LWC: Fill form
  LWC-->>Flow: List MyBox_DocGenFieldValue
  Flow->>SF: Create Case shell
  Note over Flow,Toolkit: New transaction
  Flow->>Toolkit: CreateFolderForRecordId_v2
  Note over Flow,ApexSub: New transaction
  Flow->>ApexSub: caseId folderId schema fieldValues
  ApexSub->>Toolkit: GET same pinned schema JSON
  ApexSub->>ApexSub: Validate requiredWhen omit hidden serialize
  ApexSub->>Box: POST docgen_batches
  ApexSub-->>Flow: batchId status
  Flow->>Flow: Clear collection
  Flow-->>User: Uploader and receipt
```

### End-to-end Flow (`HR_Request_Intake`)

One generic Screen Flow for all request types. Keep `HR_Check_DocGen_Status` as-is.

1. Optional catalog screen: Active pointer rows (`Request_Type__c`, key, version). An Experience page or URL may preselect `newHire` / `1.0` for the current launcher. Treat key/version as untrusted.
2. Form screen hosts `c:hrIntakeForm` (`lightning__FlowScreen`). Inputs: `schemaKey`, `schemaVersion`. Outputs: `List<MyBox_DocGenFieldValue>`, echoed key/version. The LWC loads the contract, renders, validates locally, and omits hidden fields.
3. Disable Pause, Wait, save-for-later, resume, and availability-for-input/output on sensitive resources. Same as v1.
4. Create the generic Case (`HR Request`, Origin `Web`, no Description, `HR_Intake_Managed_Provisioning__c = true`, schema key/version, status `Case Created`).
5. New transaction: `box__CreateFolderForRecordId_v2` with folder name = Case number, `optCreateRootFolder = true`. Folder id stays in `vBoxFolderId` only. Intake Cases remain excluded from `Create_Box_Folder_for_New_Case` via `HR_Intake_Managed_Provisioning__c != true`. **Do not go back to folder templates.**
6. New transaction: `MyBox_SubmitTransientCaseDocGen` with Case id, folder id, key/version, and `colDocGenFields`. Apex reloads the **same pinned schema version**, validates (including `requiredWhen`), serializes, submits. No Case DML in Apex.
7. Clear `colDocGenFields` and assignable sensitive values. Receipt: Case number and status only. `box:UIElementUpload` with `folderId`. Previous disabled after submit. Finish: `c:hrNavigateToPortalHome` (Aura `invoke`, not LWC).

Server-generated / constant paths (`request.requestDate`, `request.notificationType`) are `inputSource` `server` or `constant` in the schema. The LWC does not show them. Apex (or the LWC output mapper using schema constants plus `$Flow.CurrentDate` passed in) must still supply them in `colDocGenFields` so the validator sees required server fields. Preferred: Apex adds `schema` / `case` roots and also injects `inputSource=server` fields (`request.requestDate` = today) while the LWC/Flow supplies `inputSource=constant` from the schema (`newHireRehire`) without a Flow constant per request type.

### Privacy phase 1 vs phase 2

**Phase 1 (this document’s build):** LWC outputs the field collection to Flow. Same privacy model as v1. Fastest path; reuses folder action and transaction control.

**Phase 2 (later, only if privacy review forbids Flow interview state):** LWC keeps values in private JS and calls Apex for Case create, folder create, and submit, returning only `caseId` / `folderId` / `batchId` / `status`. Requires an Apex wrapper for `CreateFolderForRecordId`. Do not implement in the first v2 slice.

Neither phase may use `localStorage`, `sessionStorage`, URL parameters, LDS record cache, or console logging for request data.

## Schema: Box JSON plus thin Salesforce pointer

Canonical copy: **Box**. Git may keep `docs/examples/newHire_1_0_schema.json` (to be added at implementation) for review. Operators publish in Box and pin the file version on the pointer. Expect Box/git drift unless the published file is copied back.

### Salesforce pointer (`HR_DocGen_Schema__mdt`, narrowed)

One row per schema version. **No field list.** Stop reading `HR_DocGen_Field__mdt` on the v2 path; leave existing field records in the org until v1 Flow is retired.

| Field                            | Purpose                                                                                         |
| -------------------------------- | ----------------------------------------------------------------------------------------------- |
| `Schema_Key__c`                  | Stable name, e.g. `newHire`                                                                     |
| `Version__c`                     | Exact version, e.g. `1.0`                                                                       |
| `Request_Type__c`                | Catalog label, e.g. `New Hire/Rehire`                                                           |
| `Lifecycle_Status__c`            | `Draft`, `Active`, `Retired`. Only `Active` accepts new submissions                             |
| `Box_Schema_File_Id__c`          | Opaque Box file id of the JSON                                                                  |
| `Box_Schema_File_Version_Id__c`  | Pinned file version. Old Cases keep this version via the pointer that was Active at Case create |
| Catalog `Sequence__c` (optional) | Order on the picker                                                                             |

Remove runtime dependence on pointer-hosted `Box_DocGen_Template_File_Id__c` / `Box_DocGen_Template_Version_Id__c` / `Output_*` / `Max_Payload_Bytes__c` once those live in the JSON. Until cutover, v1 records may keep the old columns.

Pointer `key`/`version` must match JSON `schema.key`/`schema.version` or load fails (`SCHEMA_CONFIG_INVALID`).

Case still stores only `HR_Request_Schema_Key__c` and `HR_Request_Schema_Version__c`. That is an audit pointer to the pointer row, which pins a Box file version. It cannot reconstruct submitted values.

### Box config folder

Place schema files under a dedicated folder in the existing Box root (`372250559857`), not in Case folders and not next to templates in a way Experience users can browse. Toolkit service account read-only. No Experience App User collaboration.

Publish: upload or replace the JSON, record the new file version id, set the pointer to Active. Retire by lifecycle, not by deleting historical versions while Cases still reference that key/version.

### Schema JSON shape

No PII. No submitted values. Leaf scalar paths only (same nested-object `user_input` as v1). Max file size ~100 KB; reject larger (`SCHEMA_CONFIG_INVALID`).

```json
{
    "schema": {
        "key": "newHire",
        "version": "1.0",
        "requestType": "New Hire/Rehire"
    },
    "docGen": {
        "templateFileId": "2456566806586",
        "templateVersionId": "2724134783386",
        "outputType": "pdf",
        "outputFileNamePattern": "HR Request - {caseNumber}",
        "maxPayloadBytes": 200000
    },
    "sections": [
        { "id": "employee", "label": "Employee", "sequence": 10 },
        { "id": "assignment", "label": "Assignment", "sequence": 20 },
        { "id": "certification", "label": "Certification", "sequence": 30 },
        { "id": "compensation", "label": "Compensation", "sequence": 40 },
        { "id": "notes", "label": "Notes", "sequence": 50 },
        { "id": "submitter", "label": "Submitter", "sequence": 60 }
    ],
    "fields": [
        {
            "path": "employee.firstName",
            "valueType": "text",
            "uiControl": "text",
            "label": "Employee First Name",
            "section": "employee",
            "sequence": 20,
            "required": true,
            "maxLength": 80,
            "blankBehavior": "omit",
            "inputSource": "user"
        },
        {
            "path": "request.requestDate",
            "valueType": "date",
            "uiControl": "date",
            "label": "Today's Date",
            "section": "request",
            "required": true,
            "inputSource": "server"
        },
        {
            "path": "request.notificationType",
            "valueType": "text",
            "uiControl": "text",
            "label": "Notification Type",
            "required": true,
            "allowedValues": ["newHireRehire"],
            "constantValue": "newHireRehire",
            "inputSource": "constant"
        },
        {
            "path": "compensation.rateReason",
            "valueType": "text",
            "uiControl": "textarea",
            "label": "New Hire Rate Reason",
            "section": "compensation",
            "sequence": 20,
            "required": false,
            "maxLength": 255,
            "blankBehavior": "omit",
            "inputSource": "user",
            "visibleWhen": {
                "equals": [
                    "compensation.currentHourlyOrSalary",
                    ["Above minimum", "Above maximum"]
                ]
            },
            "requiredWhen": {
                "equals": [
                    "compensation.currentHourlyOrSalary",
                    ["Above minimum", "Above maximum"]
                ]
            }
        }
    ]
}
```

`valueType` remains `text` | `date` | `number` | `boolean` (JSON / `MyBox_DocGenFieldValue`). `uiControl` is the widget. `inputSource` is `user` | `constant` | `server`. Reserved path roots `schema` and `case` stay server-generated in Apex and must not appear in `fields`.

Full `newHire/1.0` field list, labels, requiredness, and demo choice lists stay the contract in [hr_request_demo_contract.md](hr_request_demo_contract.md). Implementation authors one Box JSON covering every mapped path. Rate reason is no longer “optional in metadata, required in Flow”: `requiredWhen` is the real rule and Apex enforces it.

### Rule DSL

Keep it small. Operators: `equals`, `notEquals`, `in`, `isTrue`, `isFilled`, `and`, `or`.

```json
{
    "equals": [
        "compensation.currentHourlyOrSalary",
        ["Above minimum", "Above maximum"]
    ]
}
```

Evaluate in the LWC for show/hide and client required. Evaluate again in `MyBox_DocGenSchemaService`. Hidden paths are omitted (v1 `Blank_Behavior__c = omit`). Stale hidden values must not reach Doc Gen.

Not a general expression engine. No Salesforce formula eval. No arbitrary Apex.

### Meta-schema validation

Treat Box JSON as untrusted. On load, Apex checks:

- JSON parse, size cap, required keys (`schema`, `docGen`, `sections`, `fields`).
- `schema.key` / `version` match the pointer.
- `docGen.templateFileId`, `templateVersionId`, `outputType`, `outputFileNamePattern` present; filename pattern allows only non-sensitive tokens (e.g. `{caseNumber}`).
- Unique valid `path` syntax (same rules as v1: lower-camel segments, max depth 4, no reserved roots).
- `valueType`, `uiControl`, `inputSource`, `blankBehavior` allow-lists. `uiControl` must be in the LWC catalog.
- `section` references a known section id for `user` fields.
- `allowedValues` typed JSON array when present (`submitter.attested` → `[true]`).
- Rule DSL well-formed; referenced paths exist.
- No scalar/object path collisions.

Failures: `SCHEMA_CONFIG_INVALID`. Box/HTTP failure: `SCHEMA_UNAVAILABLE` (form cannot open; submit must not proceed). Do not put raw Box bodies in Case or the UI.

## Schema-driven LWC (`c:hrIntakeForm`)

Well-known pattern: **schema-driven forms** (metadata-driven / JSON-schema forms). Same idea as Mozilla react-jsonschema-form, Angular Formly, SurveyJS. Salesforce Dynamic Forms are the sObject product; this LWC is the off-record version with a **closed widget catalog**.

LWC cannot instantiate an arbitrary tag from a string. Do not use `lwc:component` for v2. Pre-declare widgets and branch on `uiControl`.

### Runtime

1. Imperative, **non-cacheable** Apex `getFormContract(schemaKey, schemaVersion)` (callouts are illegal on `cacheable=true`).
2. Apex returns sections and user-visible fields only. **Strip** `docGen.templateFileId` and `templateVersionId` from the client payload.
3. LWC holds values in a map keyed by `path`. No LDS, no record.
4. Template: `for:each` sections, then `for:each` visible fields, `key={field.path}`.
5. `onchange` updates the map. Getters recompute visibility and required from the DSL. Hidden keys are deleted.
6. Flow Next: emit `List<MyBox_DocGenFieldValue>` plus constants from the schema. Do not emit hidden fields.

| `uiControl`                       | Component                                 |
| --------------------------------- | ----------------------------------------- |
| `text`, `email`, `number`, `date` | `lightning-input` with matching `type`    |
| `checkbox`                        | `lightning-input type="checkbox"`         |
| `textarea`                        | `lightning-textarea`                      |
| `picklist`                        | `lightning-combobox` from `allowedValues` |

Adding `newHire/1.1` or another request type does not change this template. Redeploy the LWC only for a new widget type (and extend the Apex `uiControl` allow-list).

Sketch (not production markup):

```html
<template for:each="{sections}" for:item="section">
    <section key="{section.id}">
        <h2>{section.label}</h2>
        <template for:each="{section.visibleFields}" for:item="field">
            <lightning-input
                lwc:if="{field.isText}"
                key="{field.path}"
                label="{field.label}"
                value="{field.value}"
                required="{field.required}"
                maxlength="{field.maxLength}"
                data-path="{field.path}"
                onchange="{handleChange}"
            >
            </lightning-input>
            <lightning-combobox
                lwc:elseif="{field.isPicklist}"
                key="{field.path}"
                label="{field.label}"
                value="{field.value}"
                options="{field.options}"
                required="{field.required}"
                data-path="{field.path}"
                onchange="{handleChange}"
            >
            </lightning-combobox>
        </template>
    </section>
</template>
```

Jest: fixture schema JSON; required, picklists, `visibleWhen`, hidden omit, typed output. No org CMDT required for those tests.

Targets: Experience LWR + Flow screen. Authenticated users only. SLDS; labels come from schema (English only in this POC).

## Apex contracts

Keep the invocable submit/status signatures so Flow XML changes stay small.

| Class / method                         | v2 role                                                                                                                                                                                  |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MyBox_DocGenFieldValue`               | Unchanged DTO                                                                                                                                                                            |
| `MyBox_DocGenSchemaService`            | Load pointer; GET/parse/meta-validate Box JSON; `buildUserInputMap` from parsed fields (not `HR_DocGen_Field__mdt`); honor `requiredWhen` and omit hidden                                |
| `getFormContract` (new `@AuraEnabled`) | Pointer + schema GET; return UI DTO; strip template ids                                                                                                                                  |
| Box content adapter (new seam)         | `GET /2.0/files/{id}/content?version=`; stub in tests like `MyBox_DocGenBoxAdapter`                                                                                                      |
| `MyBox_SubmitTransientCaseDocGen`      | Same inputs/outputs. Internally use parsed Box schema for validation and `docGen` template ids. Still no Case DML. Two Box callouts (schema GET + Doc Gen POST) with no DML between them |
| `MyBox_GetCaseDocGenStatus`            | Unchanged                                                                                                                                                                                |

Submit still verifies Case access, intake flag, Case schema pointer vs requested key/version, eligible status, no existing batch id, and folder association via `box.Toolkit.getFolderIdByRecordId`.

First v2 slice: one schema GET per form open and one per submit. No Platform Cache.

Tests: JSON fixtures in memory for validator/meta-schema (replace in-memory CMDT field construction in `MyBox_DocGenSchemaServiceTest`). Adapter stub for content GET. Do not require deployed field CMDT for the new path.

## What a new schema looks like

1. Author Box schema JSON (fields, UI, rules, `docGen` template pin).
2. Author/pin the Word Doc Gen template; put file/version ids in `docGen`.
3. Upload JSON to the config folder; set thin pointer Active.
4. No Flow copy. No Apex/LWC change unless a new `uiControl` or DSL operator is required.

`newHire/1.1` proof: optional `request.referenceNote` (text), updated template tag, new pointer (or new file version) `newHire` / `1.1`. `1.0` rejects that path.

## Transaction, failure, and status

Same Case statuses, sanitized error codes, and fault rules as v1 ([hr_request_demo_tooling.md](hr_request_demo_tooling.md) transaction table), plus:

| Outcome                                      | Behavior                                                         |
| -------------------------------------------- | ---------------------------------------------------------------- |
| Schema GET or parse fails before form render | `SCHEMA_UNAVAILABLE`; do not create a Case                       |
| Schema GET fails at submit                   | `Doc Gen Submit Failed` / `SCHEMA_UNAVAILABLE`; clear collection |
| Schema JSON invalid                          | `SCHEMA_CONFIG_INVALID`                                          |
| `requiredWhen` fails                         | `REQUIRED_BLANK` (or existing required code); no Doc Gen call    |

`HR_Check_DocGen_Status` unchanged. Never retrieve generated content or original `user_input` for status.

## Experience, access, and security

Same site (`/portal/s/hr-request`), users A/B, permission set `MyBox_HR_DocGen_Access`, Box App User, Case OWD. Add Apex class access for `getFormContract` and the content adapter. Catalog/form must not expose Box schema file ids to the browser if they are not required for UX; template ids must not.

Experience users must not access the schema config folder. Substituted Case/folder ids still rejected at submit.

Keep v1 Flow Active as fallback until v2 is proven. Form open now depends on Box availability (v1 CMDT did not).

## Focused test plan (v2 additions)

| Area             | Evidence                                                                                                                               |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Schema-driven UI | `newHire/1.0` shows every contract field with correct control type; constants/server fields hidden; attestation true-only              |
| Rules            | Rate reason visible/required only for Above minimum / Above maximum; hidden value omitted from `colDocGenFields` and from `user_input` |
| Box schema load  | Pinned version used; pointer/JSON key mismatch fails; oversized/invalid JSON fails; GET failure is `SCHEMA_UNAVAILABLE`                |
| Client contract  | Form DTO has no template file/version ids                                                                                              |
| Flexibility      | `1.1` renders `request.referenceNote` with unchanged LWC/Apex; `1.0` rejects it                                                        |
| Regression       | v1 PII boundary, folder exclusion, status Flow, Home navigation, user B isolation                                                      |

## Implementation chunks

These are work packets after this document. Do not implement as part of authoring it.

| Chunk | Deliverable                                                                                                                                     | Depends on  |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| V2-0  | Box config folder, service-account read, no Experience collaboration                                                                            | v1 Box root |
| V2-1  | `newHire/1.0` schema JSON from [hr_request_demo_contract.md](hr_request_demo_contract.md); example file in `docs/examples/`; upload and pin ids | V2-0        |
| V2-2  | Narrow pointer CMDT fields; one Active `newHire/1.0` pointer row                                                                                | V2-1        |
| V2-3  | Content GET adapter, meta-schema, refactor `MyBox_DocGenSchemaService`, `getFormContract`, `requiredWhen`; Apex tests                           | V2-2        |
| V2-4  | `c:hrIntakeForm` + Jest; generic `HR_Request_Intake`; Experience wiring beside v1                                                               | V2-3        |
| V2-5  | End-to-end `1.0` on Experience (synthetic); keep v1 until pass                                                                                  | V2-4        |
| V2-6  | `newHire/1.1` JSON + template + pointer only                                                                                                    | V2-5        |
| V2-7  | Retire v1 field-CMDT runtime path and `HR_New_Hire_Intake` when v2 is the launcher                                                              | V2-6        |

v1 chunks 7–8 (Flow copy + runbook) are superseded: no `HR_New_Hire_Intake_Schema_Demo`. Runbook updates belong with V2-5/V2-6.

## Assumptions

- Box is canonical for schema JSON; Salesforce stores only the pointer.
- Phase 1 Flow collection of field values remains acceptable, same as v1.
- Folder action stays `box__CreateFolderForRecordId_v2`.
- Leaf scalars only; no repeatable groups in this slice.
- OmniScript / Dynamic Forms / record-backed forms are out.
- Existing submit/status Apex, Case fields, and Experience permissions remain the orchestration backbone.
- Real HR data and a platform-wide no-persistence guarantee remain out of scope.
