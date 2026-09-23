# HR Request Intake v3 — Manual Multi-screen Flows and Box-hosted Contract

## Relationship to v1 and v2

[hr_request_demo_tooling.md](hr_request_demo_tooling.md) is the **as-built v1 plan**: a New Hire/Rehire Screen Flow, `HR_DocGen_Field__mdt` rows, and schema-neutral `MyBox_SubmitTransientCaseDocGen`. Current org state: [hr_request_demo_status.md](hr_request_demo_status.md). Frozen field map: [hr_request_demo_contract.md](hr_request_demo_contract.md).

[hr_request_demo_tooling_v2.md](hr_request_demo_tooling_v2.md) is the **schema-driven LWC plan**. It moves the field contract to a versioned JSON file in Box and renders one screen by looping a closed widget catalog. Conditional show/hide is a small JSON rule DSL.

This v3 document is a **third option**. It keeps v2's Box JSON as the payload contract and keeps v1's admin-built Screen Flow as the form. Use it when a request type needs several screens, skipped steps, or branch-specific pages that are awkward to represent by generating one LWC screen from the schema.

v1 stays Active. Authoring this design does not deactivate `HR_New_Hire_Intake` and does not require the v2 LWC.

v1 proved:

- Transient JSON Doc Gen through `box.DocGenToolkit.submitDocGenBatch` (`POST /2.0/docgen_batches`) with no request PII on Case.
- One generic validator/serializer with no New Hire branches.
- Folder create via `box__CreateFolderForRecordId_v2` (folder name = Case number), Box uploader/explorer, and manual status refresh.

v2's scaling win is real for flat forms: a new field is a JSON and template publish, with no Flow edit. That win depends on one generated screen and a DSL that can express every visibility and requiredness rule. A wizard whose next screen depends on prior answers, that skips an entire step, or that uses a Flow-native choice lookup is Flow Builder's job. Encoding that graph inside `hrIntakeForm` would mean building a second interview runtime.

## Summary

Authenticated Experience Cloud intake still:

1. Collects request data in an active Screen Flow (synthetic HR data only).
2. Creates a non-sensitive Case shell.
3. Creates the Case Box folder (`box__CreateFolderForRecordId_v2`, folder name = Case number).
4. Submits an in-memory JSON payload to Box Doc Gen.
5. Presents the Box uploader and a receipt, then navigates Home via `c:hrNavigateToPortalHome`.

Box remains the system of record for the generated PDF, supporting files, and the form/validation schema.

What changes relative to v1 and v2:

| Concern                | v1                                                     | v2                                                                                | v3                                                                                     |
| ---------------------- | ------------------------------------------------------ | --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Form UX                | Standard Screen Flow components, one Flow per schema   | One Flow-screen LWC loops a schema                                                | Admin-built multi-screen Flow, Decisions, and visibility                               |
| Field contract         | `HR_DocGen_Field__mdt` (one row per path)              | One versioned JSON file in Box                                                    | Same Box JSON as v2. No field CMDT                                                     |
| Schema pointer         | CMDT key/version plus template ids and every field row | Thin pointer: key, version, lifecycle, Box schema file id, pinned file version id | Same thin pointer as v2                                                                |
| Template ids           | On `HR_DocGen_Schema__mdt`                             | Inside the Box schema JSON (`docGen`)                                             | Inside the Box schema JSON (`docGen`)                                                  |
| Conditional navigation | Flow Decisions / component visibility                  | JSON rule DSL on one screen                                                       | Flow owns which screen is shown. Apex enforces the DSL only against values it receives |
| Screen-to-path map     | Assignment elements into `colDocGenFields`             | LWC emits `List<MyBox_DocGenFieldValue>`                                          | Same Assignment list as v1. Apex checks it against the Box schema                      |
| New visible field      | Flow edit plus CMDT row plus template                  | Box JSON plus template. No Flow edit                                              | Flow edit plus Box JSON plus template. No Apex edit                                    |
| New request type       | Copy the Flow                                          | New JSON, same Flow and LWC                                                       | New Flow. Same submit action and schema loader                                         |
| OmniStudio             | Not used                                               | Not used                                                                          | Not used                                                                               |

Reuse without change of meaning: `MyBox_DocGenFieldValue`, `MyBox_SubmitTransientCaseDocGen` invocable inputs/outputs, `MyBox_GetCaseDocGenStatus`, the seven Case orchestration fields, `HR_Check_DocGen_Status`, Box UI Elements, and `box__CreateFolderForRecordId_v2`.

## Privacy boundary

PII and privacy matter where a value would be stored permanently on a Salesforce record. In-flight and in-memory storage is acceptable.

Allowed:

- Screen component values in the active Flow interview, including across multiple screens and Next clicks.
- Flow variables, formulas, and the `colDocGenFields` collection.
- Apex heap, including the nested `user_input` object and the serialized Doc Gen body for the duration of the submit callout.

Forbidden as permanent Salesforce record data:

- Request-subject identity, contact, compensation, certification, notes, or any other form value on Case or any other sObject.
- The JSON payload, a payload fragment, or a generated filename that contains a request-subject value.
- Uploaded supporting documents or generated PDF content as Salesforce Files.
- Custom objects, Notes, Tasks, Platform Events, or Custom Metadata records that store submitted answers.
- A paused or saved-for-later interview. Pause writes the interview to a Salesforce record. Leave Pause, Wait, and save-for-later off.

The Case may store only orchestration data: schema key and version, integration status, the intake-provisioning flag, the Doc Gen batch id, the output file id, a sanitized error code, and standard audit fields such as `CreatedById`. Description stays blank. Subject stays a generic label such as `HR Request`.

Clearing interview variables after submit is optional hygiene. It is not required to meet this boundary. v2 phase 2 (an LWC that keeps values in private JavaScript and calls Apex so they never enter the Flow) is not a v3 requirement.

Synthetic HR data remains the rule for development, testing, and demonstrations.

## What "generic mapping" can and cannot do

`MyBox_SubmitTransientCaseDocGen` is already the generic action. Its signature does not change when a form field is added:

```text
SubmitTransientCaseDocGen.Request
  caseId        = {!vCaseId}
  boxFolderId   = {!vBoxFolderId}
  schemaKey     = {!cSchemaKey}
  schemaVersion = {!cSchemaVersion}
  fieldValues   = {!colDocGenFields}
```

`colDocGenFields` is a list of `MyBox_DocGenFieldValue`:

```text
path: String
valueType: String        // text, date, number, or boolean
textValue: String
dateValue: Date
numberValue: Decimal
booleanValue: Boolean
```

For a nonblank entry, exactly one typed value property is populated. Boolean `false` and numeric zero are values. Flow builds this list with Assignment elements after the folder id exists. Apex validates it against the Box schema, injects server-generated values, serializes with `JSON.serialize`, and submits. Flow does not build the JSON string.

An action that discovers screen outputs by component API name is not possible. An invocable method receives only the arguments that Flow element is wired to. Flow has no runtime dictionary of screen component values, and `Map` is not an invocable type. A schema property such as `flowResource: "inEmployeeFirstName"` would not read that component. The binding is the Assignment that copies `{!inEmployeeFirstName}` into a `MyBox_DocGenFieldValue`.

That explicit wire is the form's mapping, and it lives in the Flow on purpose. Admins author the wizard in Flow Builder. The Box schema is the contract those wires must satisfy. It does not render the wizard and it does not look up Flow resources.

Per-field invocable actions, and a fixed slot list (`value1` … `value40`), are the same wire with a lower ceiling. v3 does not add them.

## Architecture

```mermaid
sequenceDiagram
  actor User
  participant Flow as ManualIntakeFlow
  participant SF as PointerAndCase
  participant Apex as SubmitTransientCaseDocGen
  participant Toolkit as BoxToolkit
  participant Box as BoxContentAndDocGen

  User->>Flow: Complete multi-screen wizard
  Flow->>Flow: Decisions, visibility, branch-specific screens
  Flow->>SF: Create generic Case shell
  Note over Flow,Toolkit: New transaction
  Flow->>Toolkit: CreateFolderForRecordId_v2
  Toolkit-->>Flow: Folder id
  Flow->>Flow: Assignments build colDocGenFields
  Note over Flow,Apex: New transaction
  Flow->>Apex: caseId, folderId, schema key/version, fieldValues
  Apex->>SF: Thin pointer for the pinned schema file
  Apex->>Toolkit: GET files/id/content pinned version
  Toolkit->>Box: Schema JSON
  Apex->>Apex: Validate, inject server fields, serialize
  Apex->>Box: POST /2.0/docgen_batches
  Apex-->>Flow: batchId, status, errorCode
  Flow-->>User: Uploader and receipt
```

### End-to-end Flow

One Screen Flow per wizard (per request type, or per major variant that needs its own screen graph). `HR_Check_DocGen_Status` stays as it is. v3 does not replace `HR_New_Hire_Intake` until a v3 Flow for that request type is proven.

1. Render the wizard with standard Text, Email, Date, Checkbox, Picklist, and Text Area components. Use Decisions to choose the next screen, skip a step, or show a branch-specific page. Component visibility is available for fields that share a screen.
2. Schema key and version are Flow constants or launcher inputs, treated as untrusted at submit. They are not typed by the end user as free text.
3. On submit, validate in the Flow before creating a Case. Create the generic Case (`HR Request`, Origin `Web`, no Description, `HR_Intake_Managed_Provisioning__c = true`, schema key/version, status `Case Created`). No form value is written to the Case.
4. New transaction: `box__CreateFolderForRecordId_v2` with folder name = Case number. Folder id stays in `vBoxFolderId`. Intake Cases stay excluded from `Create_Box_Folder_for_New_Case` via `HR_Intake_Managed_Provisioning__c != true`.
5. Build `colDocGenFields` with section Assignment elements (`Build_Employee_Fields`, and so on). Use a distinct `fv...` resource per field. No screen, Pause, Wait, subflow boundary used as a persistence point, or logging action between those Assignments and `MyBox_SubmitTransientCaseDocGen`.
6. New transaction: `MyBox_SubmitTransientCaseDocGen` with Case id, folder id, key/version, and `colDocGenFields`. Apex reloads the pinned schema, validates, serializes, and submits. No Case DML in Apex.
7. Flow writes only the returned batch id, integration status, and sanitized error code. Receipt shows Case number and status. `box:UIElementUpload` uses `folderId`. Finish calls `c:hrNavigateToPortalHome`.

Server and constant paths (`request.requestDate`, `request.notificationType`) are `inputSource` `server` or `constant` in the Box schema. The Flow does not collect them and does not need a per-request-type constant for them. Apex injects `request.requestDate` (today) and constant values from the schema, and Apex alone adds the reserved `schema` and `case` roots.

### Conditional logic

Flow owns screen order, skipped pages, and branch-specific screens. A screen the user never visits contributes no assignments, so its paths are absent from `colDocGenFields`.

Apex owns the structural contract: known paths, types, unconditional `required`, `requiredWhen`, allowed values, blank behavior, and size limits. It has no New Hire-specific branches.

`requiredWhen` and `visibleWhen` in the Box JSON are evaluated against the collection Apex received:

- A required path that is missing fails submit.
- A `requiredWhen` rule whose condition is true and whose path is missing fails submit.
- A value whose `visibleWhen` is false is omitted so a stale answer is not merged.

A condition that exists only as Flow navigation ("the certification-history screen was skipped") is satisfied by not emitting those paths. Apex cannot reconstruct which screen was shown. Put a rule in the DSL when Apex must enforce it even if the Flow emits the value. Leave it in the Flow when it is purely about which page comes next.

Hiding a component does not clear its value. `HR_New_Hire_Intake` already cannot assign a blank back onto the rate-reason screen component. On a branch that does not apply, copy the screen component into a variable, blank that variable, and map the variable into `colDocGenFields`.

### Stale-value pattern

```text
vRateReason = {!inRateReason}
Decision: compensation is Above minimum or Above maximum
  yes -> keep vRateReason
  no  -> vRateReason = null

fvRateReason.path       = "compensation.rateReason"
fvRateReason.valueType  = "text"
fvRateReason.textValue  = {!vRateReason}
colDocGenFields         Add {!fvRateReason}
```

Apex still applies `blankBehavior` and `visibleWhen` from the schema. The variable copy is what makes the inapplicable branch actually blank.

## Schema

Canonical copy is the Box JSON file specified in [hr_request_demo_tooling_v2.md](hr_request_demo_tooling_v2.md): `schema`, `docGen`, `sections`, `fields`, `valueType`, `inputSource`, `blankBehavior`, `allowedValues`, `visibleWhen`, and `requiredWhen`. Same meta-schema checks, same size cap, same error codes (`SCHEMA_CONFIG_INVALID`, `SCHEMA_UNAVAILABLE`).

v3 uses that file as a contract, not as a renderer.

- `sections` and `uiControl` may be present so one JSON can also feed the v2 LWC. A v3 Flow ignores them.
- `path`, `valueType`, `required`, `requiredWhen`, `visibleWhen`, `allowedValues`, `maxLength`, `blankBehavior`, and `inputSource` are enforced at submit.
- Reserved roots `schema` and `case` stay out of `fields` and out of the Flow collection.
- Leaf scalars only, same as v1 and v2. Repeatable groups are out of this option.
- The thin `HR_DocGen_Schema__mdt` pointer is the v2 pointer: key, version, lifecycle, `Box_Schema_File_Id__c`, `Box_Schema_File_Version_Id__c`. No field-list CMDT on this path. Pointer key/version must match JSON `schema.key` / `schema.version`.
- Template file and version ids live under `docGen` in the JSON. Runtime submission still goes through `box.DocGenToolkit.submitDocGenBatch` (`POST /2.0/docgen_batches`, `box-version: 2025.0`). The schema GET is `GET /2.0/files/{file_id}/content` with the pinned version, via `box.Toolkit.sendRequest`, without the Doc Gen version header.
- Schema JSON is configuration. It contains no submitted values and no sample PII. Experience users cannot browse the config folder.

Two artifacts must be updated together for a new visible field: the Flow (component, branch, Assignment) and the Box JSON (path, rules, template pin). Submit fails closed when the Flow sends an unknown path or omits a required path. A Flow-only navigation rule that never emits a field is invisible to Apex; that is expected.

`newHire/1.1` on a v3 Flow means adding `request.referenceNote` to the wizard and to the JSON, plus a template tag. Apex source does not change. This option does not claim a JSON-only field add. That claim belongs to v2.

## Apex

| Class / method                    | v3 role                                                                                                                                                                                                               |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MyBox_DocGenFieldValue`          | Unchanged DTO. The Flow Assignment target                                                                                                                                                                             |
| `MyBox_DocGenSchemaService`       | Load the thin pointer; GET and meta-validate Box JSON; validate the Flow collection; honor `requiredWhen`; omit values whose `visibleWhen` is false; inject `inputSource` `server` and `constant`; build `user_input` |
| `MyBox_SubmitTransientCaseDocGen` | Same inputs and outputs. No Case DML. Two Box callouts (schema GET, then Doc Gen POST) with no DML between them                                                                                                       |
| `MyBox_GetCaseDocGenStatus`       | Unchanged                                                                                                                                                                                                             |

If the v2 loader already does this, v3 calls it. v3 does not add a second validator with New Hire branches, and it does not keep reading `HR_DocGen_Field__mdt` on the v3 path.

Submit still verifies Case access, the intake flag, the Case schema pointer against the requested key/version, eligible status, no existing batch id, and the folder association via `box.Toolkit.getFolderIdByRecordId`.

There is no `getFormContract` call on the v3 path. The Flow does not download the schema to render itself.

## Transaction, failure, and status

Case statuses, sanitized error codes, fault paths, and the two callout transaction boundaries match v1 ([hr_request_demo_tooling.md](hr_request_demo_tooling.md)) and the v2 additions for schema load ([hr_request_demo_tooling_v2.md](hr_request_demo_tooling_v2.md)):

| Outcome                                                             | Behavior                                                                                                     |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Flow validation fails                                               | Correct the wizard before creating a Case                                                                    |
| Folder creation fails                                               | Sanitized fault path; save `Folder Failed` when possible; exit                                               |
| Schema GET or parse fails at submit                                 | `Doc Gen Submit Failed` / `SCHEMA_UNAVAILABLE`                                                               |
| Schema JSON invalid                                                 | `SCHEMA_CONFIG_INVALID`                                                                                      |
| Unknown path, type mismatch, or `required` / `requiredWhen` failure | Fixed validation code; no Doc Gen call                                                                       |
| Box accepts                                                         | Save batch id and status only                                                                                |
| Box later reports generation failure                                | `Doc Gen Failed`. A new PDF requires the user to submit again, because the payload is not stored on the Case |

`HR_Check_DocGen_Status` is unchanged. Status refresh never retrieves generated content or the original `user_input`.

## When to use v3

Use v3 when at least one of these is true:

- The next screen depends on an earlier answer.
- An entire step is skipped for some submissions.
- A branch has its own page, not a hidden field on a shared page.
- A choice list comes from a non-PII Flow lookup (dynamic record choice). Those lookup records must themselves contain no request-subject PII.

Use v2 when the form is one screen, or a single scroll of sections, and the goal is to add a field by publishing JSON and a template without editing a Flow.

Both can share one Box schema file and one submit action. A request type picks one UX. It does not run the LWC and a manual wizard for the same submission.

## Out of scope

- Schema-driven rendering (`c:hrIntakeForm`) on the v3 path.
- A `screens` / `nextWhen` interpreter inside an LWC.
- An Apex or local action that reads screen components by API name.
- Per-field submit actions, or a fixed-capacity slot signature.
- OmniStudio, Dynamic Forms, and Assessment/Survey objects that store answers.
- Field Service Data Capture. That product persists responses on Salesforce records.
- Repeatable row groups.
- Pause, Wait, and save-for-later.
- Deactivating v1 as part of writing this design.

## Assumptions

- Permanent Salesforce record storage is the PII boundary. Active Flow state and Apex heap are allowed.
- Box is canonical for schema JSON. Salesforce stores the thin pointer and the Case orchestration fields.
- The wizard is one active Screen Flow interview from the first screen through Doc Gen submit.
- Folder create stays `box__CreateFolderForRecordId_v2`.
- Leaf scalars only.
- The existing submit and status actions, Case fields, and Experience permissions remain the orchestration backbone.
- Real HR data remains out of scope for the demo. Synthetic values only.
