# Salesforce Case Intake and Box Doc Gen

## Summary

Build an authenticated Experience Cloud Screen Flow for the New Hire/Rehire intake represented in [new_hire_smartsheet.pdf](../artifacts/new_hire_smartsheet.pdf). The Flow will collect request data transiently, create a non-sensitive Case shell, synchronously create the Case's Box folder, submit an asynchronous PDF Doc Gen job using an in-memory JSON payload, and then present the Box uploader.

Salesforce must not persist request-subject PII or sensitive HR data. This includes names, employee identifiers, SSNs, birth dates, addresses, email addresses, compensation, certification details, notes, the complete form payload, and values derived from those fields. No custom Salesforce object will store request data. Box is the system of record for the generated document and supporting files.

The design uses Box for Salesforce 5.53 already installed in the org. Box's native record-based Doc Gen action will not be used because there is deliberately no Salesforce record containing the merge data. A schema-neutral Apex action will construct the payload in memory and call `box.DocGenToolkit.submitDocGenBatch`, which supports arbitrary JSON input through the [Box Doc Gen batch API](https://developer.box.com/guides/docgen/generate-document).

## Demo Scope and Acceptance Criteria

The complete specified New Hire/Rehire form and a flexible, metadata-driven payload schema are required demo capabilities. Keep all mapped form fields, applicable conditional behavior, and submitter attestation. The implementation uses one primary admin-maintained intake Screen Flow, a copy for the schema-extension demonstration, a separate status Flow, two Custom Metadata Types, and one schema-neutral Apex submission action.

“Flexible schema” means adding an approved field or schema version without changing the Apex submission service. The Flow resource/mapping and Box template still need corresponding changes. Metadata-driven form rendering and a custom form LWC are outside this demo.

The demo is complete when:

1. An authenticated Experience user submits the full specified form using synthetic HR data.
2. One generic Case and its managed Box folder association are created; the PDF contains the mapped values.
3. The user uploads a synthetic supporting file directly to Box and previews both files.
4. A manual **Check document status** action reports document generation independently of upload completion.
5. A second configuration, `newHire/1.1`, adds one optional field and renders it with an updated template using unchanged Apex. Keep the full `1.0` form intact; a second complete business form is unnecessary.
6. Focused negative and access tests establish the observed application-level storage boundary and record any unverified platform behavior.

Supporting uploads are optional for application completion in this POC, but the presenter must demonstrate one successful upload. `Document Generated` means the PDF is available; it does not mean attachments, HR review, or approval are complete. The existing exclusion of “Send me a copy of my responses” remains because response delivery is outside the Box-only content workflow.

Defer scheduled polling, batch processing, backoff and overlap management, webhooks, completion notifications, automated schema release gates, a conditional-rule expression engine, dynamic form rendering, and dedicated failed-Case resume/re-entry tooling. Recovery and demo reset are manual.

### Documented capabilities used by this plan

Treat documented Salesforce type support and Box JSON submission as established capabilities. Implement the final classes directly; no capability-proving spike classes or throwaway Flows are required.

Salesforce's Help article [Considerations for the Apex-Defined Data Type](https://help.salesforce.com/s/articleView?id=platform.flow_considerations_apex_data_type.htm&language=en_US&type=5) explicitly supports Boolean, Integer, Long, Decimal, Double, Date, DateTime, and String, as single values and lists. The descriptor uses these supported types:

| Form value | Descriptor field / Apex type | Outbound JSON representation |
| --- | --- | --- |
| Text | `textValue: String` | String |
| Date | `dateValue: Date` | ISO date string (`YYYY-MM-DD`); JSON has no native date type |
| Number | `numberValue: Decimal` | Number |
| Checkbox | `booleanValue: Boolean` | Boolean |

Follow the documented DTO requirements: a top-level class, `@AuraEnabled` fields, and an accessible no-argument constructor. Do not use getter methods or a list-of-lists field on the Apex-defined Flow variable. Apply the invocable annotations to the action contract as described below.

Box's developer guide [Generate documents](https://developer.box.com/guides/docgen/generate-document) accepts JSON in `document_generation_data.user_input`, including nested structures. The payload can vary with the selected schema and does not require a Salesforce record containing merge values. “Flexible” refers to the JSON field structure; Flow still passes the typed descriptor collection, and Apex validates it against the configured contract.

Tests cover our field mappings, validation, blank handling, access controls, configured transactions, template output, and error handling. They do not independently re-test whether Salesforce supports the documented primitive types or whether Box accepts JSON. Environment readiness concerns entitlement, authorization, permissions, identifiers, and configuration; the final end-to-end check remains in chunk 6.

## Data Residency and Persistence Boundary

### Demo evidence and limitations

Use synthetic HR values and synthetic supporting documents for all development, testing, and demonstrations. The target remains no request-content persistence in Salesforce; synthetic data does not authorize intentional payload storage.

Treat active, non-paused Flow variables and Apex heap values as transient processing for the POC. Disabling Pause and clearing variables do not prove that the platform never persists values. Salesforce can save failed Flow interviews and include variable assignments in error emails; see [Flow error emails and saved interviews](https://help.salesforce.com/s/articleView?id=platform.flow_troubleshoot_email_limitations.htm&language=en_US&type=5).

Connect fault paths on record operations and integration actions, map errors to fixed codes, and never forward `$Flow.FaultMessage` or raw package exceptions. Check failed interviews, error emails, debug traces, and managed-package diagnostics using synthetic marker values. Clear assignable variables and collection entries, disable Previous navigation after submission, and end the sensitive interview promptly. Document screen outputs or platform state that cannot be explicitly cleared; do not claim guaranteed memory erasure.

Passing these checks demonstrates the observed application behavior. A platform-wide no-persistence guarantee, real HR data use, and production privacy/retention review remain outside the POC acceptance claim.

### Prohibited in Salesforce

The following must never be written to a Salesforce record, Salesforce File, Note, Task, Platform Event, Platform Cache entry, paused or failed Flow interview, async Apex job, debug log, integration log, exception message, or Flow error email:

- Any form-entered request-subject identity or contact value.
- SSN, birth date, address, email, employee ID, salary, pay rate, certification number, or sensitive notes.
- The complete JSON payload or any fragment containing a sensitive value.
- Uploaded supporting documents or generated document content.
- A generated filename containing the request subject's name or another sensitive value.

Do not use Queueable, Batch, Future, Scheduled Apex, Platform Events, or another serialized Salesforce mechanism to carry the payload. Box Doc Gen processing can be asynchronous only after the payload has been synchronously accepted by Box.

### Permitted in Salesforce

Salesforce may retain only non-sensitive orchestration metadata:

- Case ID and Case number.
- Generic request type, schema key/version, integration status, and audit timestamps.
- Opaque Box folder, Doc Gen batch, and output file IDs.
- Sanitized error codes that contain no request values or Box response body.
- Standard authenticated-user audit fields required by Salesforce, such as `CreatedById`.
- Box managed-package folder-association records, provided they contain only Salesforce and Box identifiers and no request data.

Operational reporting in Salesforce is therefore limited to request counts, processing state, timestamps, and integration failures. Reporting on the employee, compensation, certifications, or other form values must occur in the approved HR system or Box, not Salesforce.

## Implementation Changes

### End-to-end Flow

1. Add a New Hire/Rehire Screen Flow to Experience Cloud with standard screen components covering:
   - Employee identity and contact fields.
   - Region, district, station, start date, rehire status, title, dual role, department, manager, and employment status.
   - Certification details, compensation category/reason, and notes.
   - Submitter attestation.
2. Keep all entered values in active Flow variables only. Disable Pause, Wait, save-for-later, resume, and input/output variable exposure. Do not place a screen, asynchronous action, or logging action between payload assembly and Doc Gen submission.
3. Limit v1 to New Hire/Rehire. Other request types become separate Screen Flows that reuse the same transient Apex interface.
4. On submit:
   - Validate required fields, choices, cross-field rules, and attestation before record creation. Generic schema validation also runs in Apex before any Doc Gen callout.
   - Create a Case shell with a generic subject such as `HR Request`, generic Type/Origin/Status values, and no Description or form-derived values.
   - Mark the Case as intake-managed using a non-sensitive provisioning field.
   - Call `box__CreateFolderForRecordIdFromTemplate_v2` with the Case ID and configured folder-template ID. Use a generic Box folder name based only on the Case number.
   - Configure the folder action to start a new Flow transaction so the Case is committed before the Box callout, as supported by [Salesforce Flow transaction control](https://help.salesforce.com/s/articleView?id=flow_concepts_transaction.htm&language=en_US).
   - Let the Box managed package persist the Case-to-folder association in `box__FRUP__c`. Keep the folder ID returned by the action only in an active Flow variable for the immediate Doc Gen and uploader steps; do not copy it to a Case field.
   - Build the typed collection and call `SubmitTransientCaseDocGen` with transaction control set to start a new transaction too. This commits the managed folder association before the next callout. The action validates Case access, verifies the supplied folder matches the Case association, validates the collection, serializes JSON in memory, and returns only non-sensitive identifiers/status.
   - Flow owns all intake Case writes. Set the schema key/version and provisioning flag when creating the shell; after the callout, save only the returned batch ID, integration status, and sanitized error code. Submission Apex does not perform Case DML. The folder relationship remains owned by the Box managed package.
   - Clear assignable sensitive Flow variables and the field collection on success and handled failure before rendering the next screen; failures exit to manual recovery, without an in-memory retry loop.
5. Show the managed Box Content Uploader on the next Flow screen with the returned folder ID. Files go directly to Box; no Salesforce `ContentVersion` or other staging record is created.
6. Show a receipt containing only the Case number and non-sensitive integration status. Do not echo the request subject's name, email, compensation, or other form values.
7. Provide a manual **Check document status** action on the Experience Case page and a receipt link to that page. It takes only the authorized Case ID; users may run it again while Box is processing.
8. Add Box Content Explorer to the Experience Cloud Case page with preview, upload, and download enabled; disable delete, rename, share, and folder creation. The supported component properties are documented in [Box UI Elements for Salesforce](https://developer.box.com/guides/tooling/salesforce-toolkit/ui-elements).

### Transient form construction and Apex handoff

#### Recommended v1 pattern

Use standard Screen Flow components for the fixed New Hire/Rehire form. A custom LWC is not required for v1, and there is not a separate Apex action for every field. Salesforce makes each screen component's entered value available as a Flow resource after the user leaves the screen. Flow Assignment elements package those resources into a typed, in-memory collection, and one `SubmitTransientCaseDocGen` Apex action receives the complete collection. Salesforce documents both [screen components as Flow resources](https://help.salesforce.com/s/articleView?id=sf.flow_ref_resources.htm&language=en_US&type=5) and the use of [Assignment elements to populate collections](https://help.salesforce.com/s/articleView?id=flow_ref_resources_variable_populate.htm&language=en_US&type=5).

Use this runtime sequence:

1. Render the form with standard Text, Email, Date, Checkbox, Picklist, and Text Area components. Prefer one sensitive-data screen with Sections so the values do not cross more screen boundaries than necessary.
2. Give every component a stable API name, such as `inEmployeeFirstName`, `inStartDate`, and `inCurrentCompensation`. Do not mark any PII/HR variable as available for input or output outside the Flow.
3. When the user submits the screen, run Flow formulas and Decisions for cross-field rules. Explicitly blank values from fields that became inapplicable after a controlling choice changed so hidden stale values are not sent.
4. Create the generic Case and Box folder. Do not assemble the payload collection until the folder action succeeds and the Flow has the destination folder ID.
5. Run a small group of Assignment elements named by section, such as `Build_Employee_Fields`, `Build_Assignment_Fields`, `Build_Certification_Fields`, `Build_Compensation_Fields`, and `Build_Submitter_Fields`. These are in-memory Flow operations, not Apex actions or database writes.
6. Each Assignment initializes one or more `DocGenFieldValue` Apex-defined variables from screen resources and adds them to the `colDocGenFields` Apex-defined collection.
7. Invoke `SubmitTransientCaseDocGen` once, passing the Case ID, transient folder ID, fixed schema key/version, and `colDocGenFields`. Start a new transaction at this action to commit prior managed-package DML; no extra screen or asynchronous payload handoff is needed.
8. Apex validates every path and type against custom metadata, creates the nested JSON with `JSON.serialize`, and submits it to Box. Flow never constructs JSON itself.
9. After Apex returns, retain only the batch ID and sanitized status. Clear assignable sensitive variables and the field-value collection, proceed directly to the non-sensitive upload/receipt screen, and allow the Flow interview to finish.

No Screen, Pause, Wait, save-for-later step, asynchronous action, subflow boundary, or logging action is permitted between `Build_*_Fields` and `SubmitTransientCaseDocGen`.

#### Flow resources

Create these resources in the Screen Flow:

| Resource | Flow type | Purpose |
| --- | --- | --- |
| `cSchemaKey` | Text constant: `newHire` | Selects an allow-listed schema; never user-entered |
| `cSchemaVersion` | Text constant: `1.0` | Selects the exact schema version; never user-entered |
| `vCaseId` | Text/ID variable | Generic Case shell ID |
| `vBoxFolderId` | Text variable | Folder ID returned by the Toolkit; transient in Flow |
| `fv...` variables | Apex-defined `DocGenFieldValue` | Typed descriptor for each form value |
| `colDocGenFields` | Apex-defined collection of `DocGenFieldValue` | Complete transient value set passed to the single Apex action |
| `vDocGenBatchId` and `vDocGenStatus` | Text variables | Non-sensitive outputs returned by Apex |

All sensitive availability-for-input/output flags remain disabled. The separate status-refresh Flow may accept a Case ID after validating access; the intake Flow does not accept an existing failed Case for resubmission in this POC.

`DocGenFieldValue` is a top-level Apex-defined type with an accessible no-argument constructor and Flow-visible properties. Salesforce supports Apex-defined variables and collections whose fields use supported primitive types. See [Apex-defined Flow data types](https://help.salesforce.com/s/articleView?id=platform.flow_concepts_apex_type.htm&language=en_US&type=5) and [supported Flow/LWC data types](https://developer.salesforce.com/docs/platform/lwc/guide/use-flow-data-types).

Use this logical structure:

```text
DocGenFieldValue
  path: String
  valueType: String        // text, date, number, or boolean
  textValue: String
  dateValue: Date
  numberValue: Decimal
  booleanValue: Boolean
```

For a nonblank entry, exactly one typed value property is populated. An optional blank entry may have all value properties null and follows the schema's blank policy; alternatively an omitted optional entry follows that same policy. A required blank is rejected. Boolean `false` and numeric zero are values, not blanks. For example, `employee.firstName` uses `textValue`, `assignment.startDate` uses `dateValue`, and `assignment.isDualRole` uses `booleanValue`. Apex treats `path` and `valueType` as untrusted input and verifies both against the selected schema metadata before using the value.

An Assignment element can contain multiple ordered rows. A representative employee-field assignment is:

```text
fvEmployeeFirstName.path       = "employee.firstName"
fvEmployeeFirstName.valueType  = "text"
fvEmployeeFirstName.textValue  = {!inEmployeeFirstName}
colDocGenFields                Add {!fvEmployeeFirstName}

fvStartDate.path               = "assignment.startDate"
fvStartDate.valueType          = "date"
fvStartDate.dateValue          = {!inStartDate}
colDocGenFields                Add {!fvStartDate}
```

Use a distinct `fv...` resource for each field rather than repeatedly mutating and clearing one shared Apex-defined variable. This makes the mapping auditable in Flow Builder and avoids ambiguity about whether an item already added to the collection could be affected by later assignments.

#### New Hire/Rehire mapping

The v1 Flow uses the following mapping from the attached sample form. These paths are stable contract names, not Salesforce fields.

| Sample form field | Example Flow component | Doc Gen path | Value type |
| --- | --- | --- | --- |
| Employee ID # | `inEmployeeId` | `employee.employeeId` | text |
| Employee First Name | `inEmployeeFirstName` | `employee.firstName` | text |
| Employee Last Name | `inEmployeeLastName` | `employee.lastName` | text |
| Today's Date | Formula using `$Flow.CurrentDate` | `request.requestDate` | date |
| Notification Type | Constant `newHireRehire` | `request.notificationType` | text |
| New Region | `inRegion` | `assignment.region` | text |
| New District | `inDistrict` | `assignment.district` | text |
| New Station/Corporate Location | `inStation` | `assignment.station` | text |
| Hire Date/Start Date | `inStartDate` | `assignment.startDate` | date |
| Rehire? | `inIsRehire` | `assignment.isRehire` | boolean |
| New Primary Title | `inPrimaryTitle` | `assignment.primaryTitle` | text |
| Dual role? | `inIsDualRole` | `assignment.isDualRole` | boolean |
| New Department | `inDepartment` | `assignment.department` | text |
| New Status | `inNewStatus` | `assignment.status` | text |
| New Manager | `inManager` | `assignment.manager` | text |
| Full Time/PRN Status | `inEmploymentStatus` | `assignment.employmentStatus` | text |
| Certification Level | `inCertificationLevel` | `certification.level` | text |
| TXDSHS Certification # | `inTxdshsCertificationNumber` | `certification.txdshsNumber` | text |
| Prior Certification #/State | `inPriorCertificationDetails` | `certification.priorStateDetails` | text |
| Current Hourly/Salary | `inCurrentCompensation` | `compensation.currentHourlyOrSalary` | text for v1; preserves the source form's hourly/salary representation |
| New Hire Rate Reason | `inRateReason` | `compensation.rateReason` | text |
| Notes | `inNotes` | `notes` | text |
| Person Completing Form | `inSubmitterName` | `submitter.name` | text |
| Submitter Job Title | `inSubmitterJobTitle` | `submitter.jobTitle` | text |
| Submitter Email Address | `inSubmitterEmail` | `submitter.email` | text |
| Authorized/accurate attestation | `inAttestation` | `submitter.attested` | boolean |

The upload control is not part of this collection; supporting files go directly to Box after folder creation. Do not reproduce the sample form's “Send me a copy of my responses” behavior in v1 because that would create another copy of the sensitive response outside the approved Box workflow. A generic receipt with Case number and status is sufficient unless HR/privacy approves a separate secure-delivery design.

The sample does not display SSN, birth date, or home address, but future approved fields use the same typed-entry mechanism. Adding an allowed path to custom metadata and mapping a new screen resource does not create a Salesforce field or persisted request object.

#### Validation ownership and full-form checklist

Before implementing the full form, create a field checklist against the source PDF: label, screen API name, JSON path/type, requiredness, allowed choices, visibility condition, conditional-required rule, and representative synthetic test case. Preserve every mapped field; explicitly record details the static sample does not reveal rather than inventing business rules.

- Flow owns form-specific conditions, conditional requiredness, and clearing hidden/inapplicable values. Keep conditionally required fields optional in generic metadata; no conditional-expression language is built for the POC.
- Apex owns exact schema lookup, path/type validation, unconditional requiredness, allowed values, blank handling, and size limits. It has no field-specific branches for New Hire.
- Set `submitter.attested` to required with an allowed Boolean value of `true`, so both Flow and the generic validator reject an unchecked attestation.
- Use fixed demo choice lists matching the source wherever specified. Resolve unclear choices/conditions in the checklist before the dependent form implementation.
- The original compensation field uses text in v1. Prove numeric JSON handling in focused validator tests without changing the specified form.
- Treat `schema` and `case` as reserved server-generated roots. They cannot be supplied by the field collection. Include `request.requestDate` and `request.notificationType` in metadata and the template contract.
- Use the documented typed-descriptor pattern directly for the full form. Check our assignments and blank handling in the normal implementation tests; no preliminary type-support experiment is required.

#### Apex action input

The Flow configures one Apex Action element with this logical request:

```text
SubmitTransientCaseDocGen.Request
  caseId          = {!vCaseId}
  boxFolderId     = {!vBoxFolderId}
  schemaKey       = {!cSchemaKey}
  schemaVersion   = {!cSchemaVersion}
  fieldValues     = {!colDocGenFields}
```

The invocable method receives the platform-required list of request wrappers and returns one result per request. Its result contains only `batchId`, normalized `status`, and sanitized `errorCode`. Starting with API version 66.0, custom Apex classes used as invocable action parameters require an accessible no-argument constructor; the DTO classes must satisfy that requirement. See [Salesforce's Apex Action reference](https://help.salesforce.com/s/articleView?id=platform.flow_ref_elements_apex_invocable.htm&language=en_US&type=5).

Do not build the outbound JSON with a Flow Text Template, string concatenation, or an LWC-provided JSON string. Those approaches lose type fidelity, make escaping and null handling fragile, and move schema enforcement outside Apex. The Flow passes typed values; Apex alone creates the JSON.

#### When an LWC would be required

An LWC becomes appropriate in any of these cases:

- The form must be rendered dynamically from schema configuration instead of being an admin-maintained, fixed Screen Flow.
- Privacy policy concludes that values cannot reside even in an active, non-paused Flow interview across screen requests. In that stricter interpretation, use a custom form/orchestrator LWC that keeps sensitive values in private JavaScript memory and calls the staged Apex operations directly.
- The form requires repeatable rows, sophisticated reactive validation, or a user experience that standard Flow components cannot provide.

A Flow-screen LWC that simply exposes every field as an output does not materially tighten the privacy boundary because Flow still receives and holds those outputs. To reduce Flow state, the LWC must keep the sensitive properties private, invoke Apex itself after local validation, and return only non-sensitive Case/batch/status values to Flow. It must not use browser local storage, session storage, URL parameters, Lightning Data Service record cache, console logging, or client telemetry for request data.

That LWC path also owns the multi-transaction orchestration: create the generic Case, create/associate the Box folder, then submit the sensitive Doc Gen request. It is substantially more custom code and testing than the standard Flow pattern, so it is not recommended for v1 unless the stricter privacy interpretation applies.

### UML sequence diagram

The happy path below includes both callout boundaries. Failure behavior follows the diagram.

```mermaid
sequenceDiagram
    autonumber
    actor User as Experience User
    participant Flow as Intake Screen Flow
    participant SF as Case and Metadata
    participant Toolkit as Box SF Toolkit
    participant Apex as Transient Doc Gen Apex
    participant Box as Box Doc Gen and Content
    participant Refresh as Manual Status Flow

    User->>Flow: Complete full form with synthetic HR values
    Flow->>Flow: Validate required and conditional form rules
    Flow->>SF: Create generic Case, schema pointer, provisioning flag
    Note over Flow,SF: Transaction boundary 1: commit Case before folder callout
    Flow->>Toolkit: Create Case folder from template
    Toolkit->>Box: Create generic folder
    Box-->>Toolkit: Folder ID
    Toolkit->>SF: Save managed FRUP association
    Toolkit-->>Flow: Folder ID
    Flow->>Flow: Assemble typed field collection
    Note over Flow,SF: Transaction boundary 2: commit FRUP before Doc Gen callout
    Flow->>Apex: Case, folder, schema version, typed values
    Apex->>SF: Verify Case/folder access and read schema definitions
    Apex->>Apex: Validate and serialize JSON in memory
    Apex->>Box: Submit one PDF generation job
    Box-->>Apex: Accepted batch ID
    Apex-->>Flow: Batch ID and sanitized status
    Flow->>Flow: Clear assignable sensitive values
    Flow->>SF: Save batch ID and submission status
    Flow-->>User: Uploader and generic receipt / Case link
    par Supporting upload
        User->>Box: Upload directly through managed Box uploader
    and Document rendering
        Box->>Box: Generate PDF in the Case folder
    end
    User->>Refresh: Check document status using Case ID
    Refresh->>SF: Authorize Case and read stored batch ID
    Refresh->>Toolkit: Get Doc Gen batch status
    Toolkit->>Box: Retrieve status and output details
    Box-->>Toolkit: Job status and optional output file ID
    Toolkit-->>Refresh: Result normalized to non-sensitive fields
    Refresh->>SF: Save status / opaque output ID only
    Refresh-->>User: Document Generated, processing, or sanitized issue
```

### Transaction and failure behavior

Both the folder action and submission action must start a new transaction before their callouts. Mark the custom submission invocable as callout-capable. Verify these settings through the actual Experience site; Flow debugger transaction behavior differs from live execution. See [Salesforce Flow transaction control](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_transaction.htm&language=en_US&type=5).

Flow owns Case creation and subsequent orchestration updates. Apex submission validates and calls Box synchronously, without Case DML or serialized payload state. Folder association DML remains package-owned. Box rendering continues asynchronously after acceptance.

| Outcome | Demo behavior |
| --- | --- |
| Form validation fails | Correct the form before creating a Case. |
| Folder creation fails | Follow a sanitized fault path; save `Folder Failed` when possible, clear assignable values, and exit. The operator checks for a partial folder/association before a fresh submission. |
| Validation or definite Box rejection prevents submission | Save `Doc Gen Submit Failed` with a fixed code, clear values, and exit. A fresh request requires complete re-entry after correction. |
| Submission times out, connection fails after send, or acceptance cannot be established | Save `Submission Unknown` when possible. Do not retry automatically or offer immediate resubmission. The operator checks Box first. |
| Box accepts, but saving the batch ID/status fails | Keep the returned opaque batch ID in the receipt if available and show `CASE_UPDATE_FAILED`. The existing Case can still show `Case Created`; do not assume a second DML attempt will succeed. The operator repairs IDs/status from Box evidence only. |
| Box later reports generation failure | Save `Doc Gen Failed`; manual recovery may require full re-entry because Salesforce cannot reconstruct the payload. |
| User abandons upload after acceptance | The generation job continues. Upload is optional and may be completed later from the Case page. |

Connect explicit fault paths to record and integration operations, including attempts to write error status. Terminal fault screens use fixed messages and non-sensitive identifiers only. Never copy a raw response, exception, or Flow fault message into a field, log, or receipt.

Reject another submission for a Case that already has a batch ID or an incompatible integration state. Disable Previous navigation after submission. This is a basic sequential duplicate guard, not a guarantee against concurrent clicks or uncertain network outcomes. The POC uses one active submission per demo user and manual reconciliation; distributed idempotency is deferred.

### Manual Doc Gen status refresh

Submission acceptance does not mean the PDF is finished. Provide a separate **Check document status** Screen Flow on the Experience Case page. The receipt links to that page; the user can upload while Box renders and then refresh manually. No scheduler, batch job, timed Flow loop, webhook, or payload-bearing asynchronous action is required.

1. Accept only a Case ID, verify the caller can access this intake Case, and read its stored batch ID. Do not accept arbitrary batch IDs from the browser.
2. Use the managed `getDocgenBatch` Flow action if its installed outputs and fault behavior can support the non-sensitive contract. Box lists it in [Flow actions](https://developer.box.com/guides/tooling/salesforce-toolkit/flow-actions).
3. If those outputs expose raw content/error details or cannot be normalized safely, use one small `GetCaseDocGenStatus` Apex wrapper around `box.DocGenToolkit.getDocGenBatch`. Select the implementation in chunk 5 from the documented action interface and this plan's output contract; do not build both. The wrapper takes Case ID and returns only normalized status, output file ID, and sanitized error code, without DML.
4. Perform the status callout before any Case update, with transaction control where needed. Flow owns saving the normalized result. Restrict status mutation to eligible intake Cases, retain terminal results, and do not change the submission batch ID.
5. Map the documented response fields to the single generated document's status/output. Where the response exposes per-job entries, normalize that one job explicitly. Resolve any missing SDK property detail from the package references or class signatures during final implementation.

| Box result | Case/display behavior |
| --- | --- |
| `pending` | `Doc Gen Submitted`; user can check again. |
| `processing` | `Doc Gen Processing`; user can check again. |
| `completed` with output file ID | `Document Generated`; save only that output file ID. |
| `failed` | `Doc Gen Failed` with a fixed error code. |
| Completed response without output details | Preserve prior state; show `DOCGEN_OUTPUT_MISSING` and allow another manual check/operator review. |
| HTTP 400/403/404 | Preserve generation state; show a sanitized configuration/access/not-found code for operator review. A status-read failure is not proof that generation failed. |
| HTTP 429/5xx or status-call timeout | Preserve prior state; show `DOCGEN_STATUS_UNAVAILABLE` and ask the user to check later. |
| No stored batch ID | Explain that status cannot be checked; route an uncertain submission to manual Box inspection. |

Never retrieve the generated content or original `user_input` for status tracking. Do not persist raw `DocGenResponse.error`, `mostRecentError`, response bodies, or stack traces. Clear a previous sanitized status-check error when a later check succeeds. There is no automatic timeout transition or background completion timestamp in this POC.

### Declarative versus custom work

| Capability | Implementation |
| --- | --- |
| Full specified form, choices, conditional validation | Standard Screen Flow; no custom form LWC |
| Generic Case shell and integration status writes | Intake/status Flows plus seven Case fields |
| Folder creation and association | Existing managed Box Flow action and FRUP mapping |
| Supporting upload and preview | Managed Box Content Uploader and Content Explorer |
| Typed transient handoff | `DocGenFieldValue` descriptors and one collection |
| Flexible schema and exact version selection | Two Custom Metadata Types and records |
| Generic validation and nested JSON | Schema-neutral Apex in memory |
| Arbitrary-payload submission | One custom invocable wrapping the Box Toolkit |
| Status check | Managed Flow action, or a thin Apex wrapper if the normalized-output contract requires it |
| Template alignment and schema extension proof | Manual template/tag check, rendering smoke test, and focused Apex tests |
| Failed submissions and reset | Operator runbook; no resume UI or automatic resubmission |

Locate and verify the existing `Create_Box_Folder_for_New_Case` record-triggered Flow in the target org; it is not present in the checked-in Flow inventory at this review. Exclude intake-managed Cases before activating this intake Flow so it does not race with synchronous folder creation. Inspect other Case automation that could provision folders or copy form data; modify only relevant automation during implementation.

## Interfaces and Salesforce Data Model

### Case orchestration fields

Do not create `Case_Intake_Submission__c` or any replacement object that stores request data. Add these seven non-sensitive fields only where an equivalent does not already exist:

| Case field | Purpose |
| --- | --- |
| `HR_Request_Schema_Key__c` | Contract key used for this request |
| `HR_Request_Schema_Version__c` | Exact version selected at Case creation |
| `HR_Integration_Status__c` | `Case Created`, `Doc Gen Submitted`, `Doc Gen Processing`, `Document Generated`, `Folder Failed`, `Doc Gen Submit Failed`, `Submission Unknown`, or `Doc Gen Failed` |
| `HR_Intake_Managed_Provisioning__c` | Excludes the Case from competing automatic folder provisioning |
| `Box_DocGen_Batch_Id__c` | Accepted Box batch ID |
| `Box_DocGen_Output_File_Id__c` | Generated PDF ID after manual refresh |
| `HR_Integration_Error_Code__c` | Allow-listed, non-sensitive error code |

Use standard audit timestamps for the demo. Defer attempt/poll counters, next-poll timestamps, consecutive-error counters, output-version tracking, and dedicated completion timestamps. The Box template version remains configuration metadata and is distinct from the generated output version.

The Case Subject remains `HR Request`; Description remains blank. Do not store the employee's name, identifier, dates, organizational assignment, title, manager, compensation, certification, contact information, notes, or generated filename on Case.

### Case-to-folder association

Do not add `Box_Folder_Id__c` to Case. The Box for Salesforce Toolkit creates and maintains the record-folder relationship in the managed `box__FRUP__c` object. The [Toolkit folder-association methods](https://developer.box.com/guides/tooling/salesforce-toolkit/methods/#folder-association-methods) provide `getFolderIdByRecordId`, which returns the Box folder ID associated with a Salesforce record ID.

Use the relationship as follows:

- During initial submission, use the folder ID returned by `box__CreateFolderForRecordIdFromTemplate_v2` directly as a transient Flow value. Pass it to `SubmitTransientCaseDocGen` and the Box Content Uploader without a Case update.
- At submission, verify the supplied folder matches the authorized Case using `box.Toolkit.getFolderIdByRecordId(caseId)` after the association transaction commits. On a later transaction, resolve the folder through that same method or the corresponding managed Flow action. Prefer the Toolkit interface over direct SOQL so package implementation details and multiple user-permission rows remain encapsulated.
- Allow record-page Box UI Elements to use the managed record-folder association when they support defaulting from the current record.
- Keep only Doc Gen batch/output IDs and integration state on Case. Manual status refresh does not need the folder ID.

This approach avoids redundant state and prevents drift between a custom Case field and the managed association. Box documents that each FRUP record contains a Salesforce record ID and its associated Box folder ID in its [FRUP reporting guidance](https://support.box.com/hc/en-us/articles/360043691694-Generating-a-FRUP-Report-in-the-Box-Salesforce-Integration).

### Schema configuration

#### Meaning of schema in this design

“Schema” means a versioned, non-sensitive contract that tells Apex which input paths are allowed, the JSON type for each path, how blanks are handled, and which Box template must receive the resulting payload. It is not a saved copy of a request and it does not contain default, sample, or submitted field values. This design does not require Salesforce to persist a JSON Schema document; Apex reads the equivalent contract from Custom Metadata Type records.

Salesforce Custom Metadata is appropriate because its records are deployable application metadata and can be read by Apex. Salesforce also supports metadata relationships between Custom Metadata Types, allowing each field definition to reference its parent schema version. See [Salesforce Custom Metadata Types](https://help.salesforce.com/s/articleView?id=custommetadatatypes_overview.htm&language=en_US) and [Custom Metadata Type fields](https://help.salesforce.com/s/articleView?id=platform.custommetadatatypes_fields.htm&language=en_US).

#### Persisted definition model

Create two Custom Metadata Types. These are configuration metadata, not custom business-data objects:

1. `HR_DocGen_Schema__mdt`: one record for each independently deployable schema version, for example `NewHire_1_0`.
2. `HR_DocGen_Field__mdt`: one child record for each permitted JSON leaf path in that schema version.

Recommended `HR_DocGen_Schema__mdt` fields are:

| Field | Example | Purpose |
| --- | --- | --- |
| `Schema_Key__c` | `newHire` | Stable logical schema name |
| `Version__c` | `1.0` | Exact contract version selected by the Flow |
| `Lifecycle_Status__c` | `Active` | `Draft`, `Active`, or `Retired`; only `Active` accepts new submissions |
| `Request_Type__c` | `New Hire/Rehire` | Non-sensitive administrative label |
| `Box_Folder_Template_Id__c` | Opaque Box ID | Selects the folder structure; intake Flow reads this exact schema record before provisioning |
| `Box_DocGen_Template_File_Id__c` | Opaque Box file ID | Selects the Box Doc Gen template |
| `Box_DocGen_Template_Version_Id__c` | Opaque Box file-version ID | Pins generation and tag validation to the approved template version |
| `Output_Type__c` | `pdf` | Restricts the output format |
| `Output_File_Name_Pattern__c` | `HR Request - {caseNumber}` | Allows only non-sensitive tokens |
| `Max_Payload_Bytes__c` | Approved limit | Rejects an oversized in-memory request before the callout |

Recommended `HR_DocGen_Field__mdt` fields are:

| Field | Example | Purpose |
| --- | --- | --- |
| `Schema__c` | Relationship to `NewHire_1_0` | Enforces the parent schema-version relationship |
| `Json_Path__c` | `employee.firstName` | Exact allow-listed path used by Flow, Apex, and the Box template |
| `Value_Type__c` | `text` | One of `text`, `date`, `number`, or `boolean` |
| `Required__c` | `true` | Unconditionally requires a nonblank value; conditional-required rules belong to Flow |
| `Max_Length__c` | `80` | Limits text before serialization |
| `Blank_Behavior__c` | `emptyString` | One of `emptyString`, `null`, or `omit`, subject to type rules |
| `Sequence__c` | `10` | Provides deterministic validation and assembly order |
| `Allowed_Values__c` | Optional JSON array of typed permitted values | Restricts controlled values; e.g. `[true]` for attestation; never stores submitted data |
| `Classification__c` | `PII` | Labels the kind of value expected at the path for review; it is a label only |

Use a uniqueness convention of `Schema_Key__c + Version__c` for schema records and `Schema__c + Json_Path__c` for field records. Reject duplicates during runtime configuration loading and check the demo records in focused tests/manual review; an automated deployment gate is deferred.

The metadata records are persisted in two places:

- In the Salesforce org as Custom Metadata records so Apex can read them at runtime. They contain definitions and opaque Box IDs only. Custom Metadata fields do not support Shield Platform Encryption, which is another reason never to put request values, secrets, access tokens, or sensitive examples in them.
- In the Salesforce DX project as metadata XML under the normal `objects/...__mdt` and `customMetadata` source directories. Those files are reviewed, versioned, and deployed with the application. Environment-specific Box IDs use environment-specific Custom Metadata record values supplied during deployment, not hard-coded Flow formulas.

Restrict metadata changes to the setup/deployment operator and grant runtime access as required. Keep each demonstrated schema version stable; use a new version for the extension demonstration.

#### What is persisted and what is transient

| Artifact | Contains PII or sensitive HR data? | Location and lifetime |
| --- | --- | --- |
| Schema definition and field rules | No | Custom Metadata records in each Salesforce org and metadata XML in source control; retained as configuration history |
| Flow schema key/version constants | No | Flow definition metadata; fixed for that activated Flow version |
| Schema key/version used for a request | No | `Case.HR_Request_Schema_Key__c` and `Case.HR_Request_Schema_Version__c`; retained for audit and support |
| Box Doc Gen template and tags | No request instance values | Versioned Word/Doc Gen template in Box; tags correspond to the schema paths |
| `DocGenFieldValue` collection | Yes | Intended transient Flow state; clear assignable entries after handoff and verify failure-state behavior as described above |
| Nested `user_input` object and serialized request JSON | Yes | Apex heap and outbound HTTPS request only on the Salesforce side; never inserted, cached, logged, or enqueued in Salesforce |
| Box Doc Gen submitted input | Yes | Received and processed by Box under the tenant's Box Doc Gen data-handling and retention terms; confirm those terms during privacy review |
| Generated PDF and supporting uploads | Yes | Case folder in Box under approved HR retention, access, legal-hold, and deletion policies |
| Folder association, batch ID, status, and output file ID | No | Box-managed `box__FRUP__c` and the approved Case orchestration fields |

The Case's saved key/version is only an audit pointer to the definition that was used. It is not enough to reconstruct a request because neither the schema metadata nor the Case contains the submitted values.

#### Runtime use

At submission, the activated Flow supplies fixed `newHire` and `1.0` constants plus the transient `DocGenFieldValue` collection. `SubmitTransientCaseDocGen` then:

1. Queries the one `HR_DocGen_Schema__mdt` record matching the exact key/version and requires `Lifecycle_Status__c = Active`.
2. Queries its related `HR_DocGen_Field__mdt` records and builds an in-memory map keyed by `Json_Path__c`.
3. Validates that every required path is present, every supplied path is known exactly once, the declared and populated types match, lengths/allow-lists pass, blank behavior is valid, and the total payload remains under the configured limit.
4. Rejects unknown/duplicate paths, scalar-versus-object path collisions, reserved `schema`/`case` roots, and unsafe path syntax before building JSON. Allow lower-camel-case segments and a small maximum nesting depth; do not use reflection or arbitrary Salesforce field traversal.
5. Builds nested maps using the allowed paths, adds only the non-sensitive Case ID/number and schema identity, and serializes the object in Apex memory.
6. Uses the schema record's pinned Box template file/version, destination folder, output type, and generic filename to submit the Doc Gen batch.
7. Returns only the opaque batch ID, normalized status, and a sanitized error code. It does not copy the schema definition or payload to Case.

The transient JSON sent as Box Doc Gen `user_input` has this shape:

```json
{
  "schema": {"key": "newHire", "version": "1.0"},
  "case": {"id": "...", "caseNumber": "..."},
  "request": {"requestDate": "2026-09-05", "notificationType": "newHireRehire"},
  "employee": {},
  "assignment": {},
  "certification": {},
  "compensation": {},
  "submitter": {},
  "notes": ""
}
```

Dates serialize as `YYYY-MM-DD`, booleans as JSON booleans, and numbers as JSON numbers. Follow each field’s configured blank behavior: `emptyString` is valid only for text; `null` or `omit` may be used for optional values. Required blank values always fail validation. The serialized object is constructed in Apex heap memory for the outbound request and is never deliberately saved, logged, or enqueued.

#### Template alignment and versioning

Keep schema key/version and Box template file/version selection explicit, but do not build an activation gate or release-management framework for the demo.

1. Author a Box Doc Gen template covering the full `newHire/1.0` mapping and the non-sensitive Case/schema context. The sample PDF is a form reference, not automatically a usable merge template.
2. Manually check template tags against approved paths, including the server-generated `case` and `schema` paths. The [Box template-tags endpoint](https://developer.box.com/reference/v2025.0/get-docgen-templates-id-tags) can assist where supported; confirm the actual pinned version. A tag list alone does not prove type compatibility.
3. Render a synthetic payload and visually check every mapped value, date formatting, Boolean presentation, compensation text, blank optional values, and multi-line notes.
4. Create `newHire/1.1` by adding optional text path `request.referenceNote`, an extension-only “Request reference note” field/mapping, and a corresponding Box template version. The `1.0` form remains complete and unchanged.
5. Keep two clearly labeled demo Flow definitions or launchers (`HR_New_Hire_Intake` and `HR_New_Hire_Intake_Schema_Demo`) so the presenter can run both without switching activation mid-demo. Build the second by copying the completed first Flow and adding only the version/field change. Use the same Apex classes for both.
6. Verify `1.0` rejects the extra path and `1.1` accepts/renders it; old Cases retain their original schema pointer. Both versions can stay Active for the demo. Unknown/inactive versions still fail runtime validation.

Deploy definitions and records before dependent Flows. Keep historical definitions while Cases refer to them. Draft/Retired support may remain a simple runtime status check; an automated retirement/release exercise is deferred.

### Apex contracts

- `DocGenFieldValue`: top-level Flow-visible descriptor with path, declared type, and typed value properties as defined above. Create this final class in chunk 1 using the documented constructor and annotation requirements; no preliminary binding spike is needed.
- `SubmitTransientCaseDocGen`: synchronous, callout-capable invocable taking Case ID, folder ID, schema key/version, and field collection. Return `batchId`, normalized `status`, and sanitized `errorCode` only. Flow owns Case writes.
- Submission must verify Case access, intake provisioning flag, Case schema pointer, eligible state, and folder association. Reject existing batch IDs. Treat identifiers and schema selectors as untrusted inputs even when the normal Flow supplies constants.
- Generic validation rejects unknown/inactive/ambiguous schemas, duplicate/colliding definitions or submitted paths, reserved roots, missing required values, invalid types/blanks/allowed values, and excessive field/payload sizes. It must have no New Hire-specific conditional branches.
- Build the Box request from configured template file/version IDs, `input_source=api`, `output_type=pdf`, the verified folder, a filename derived only from Case number, and one document-generation entry containing the nested `user_input`. Use the documented `box.DocGenRequest` interface; resolve any missing property detail from the package reference or class signatures while implementing the final action in chunk 3. No separate JSON-acceptance experiment is required.
- Optionally `GetCaseDocGenStatus`: thin synchronous wrapper selected only if the managed Flow action cannot satisfy the normalized-output contract. Takes Case ID and returns `status`, `outputFileId`, and `errorCode`; no Case DML.
- Services run `with sharing` and enforce the relevant CRUD/FLS and Case access for the chosen user context. Keep package debugging disabled during the demo; never log DTOs, input JSON, raw Box results, or exception details. No payload-bearing asynchronous work, cache, events, or retry records.

#### Implementation status (chunks 1, 3, 5 — Apex and supporting metadata)

Coding for the transient submission/status Apex is complete and prefixed `MyBox_` to match the existing package classes:

- `MyBox_DocGenFieldValue` — the DTO described above (`@AuraEnabled` fields only, no getters, no list-of-lists).
- `MyBox_DocGenSchemaService` — generic schema loader/validator/serializer. `loadActiveSchema`/`loadFieldDefinitions` do the CMDT SOQL; `buildUserInputMap` takes already-loaded `HR_DocGen_Schema__mdt`/`HR_DocGen_Field__mdt` and is pure logic, so it is unit-testable without any deployed configuration.
- `MyBox_SubmitTransientCaseDocGen` — the invocable action. Verifies Case access/provisioning/schema-pointer/eligible-state/existing-batch-id and the folder association (`box.Toolkit.getFolderIdByRecordId`) before validating and submitting. Performs no Case DML.
- `MyBox_GetCaseDocGenStatus` — the optional thin status wrapper, implemented because the normalized output contract (only `status`/`outputFileId`/`errorCode`, with `status = null` meaning "preserve prior state") is easiest to guarantee with a dedicated wrapper rather than the managed `getDocgenBatch` action's raw `DocGenResponse` output.
- `MyBox_DocGenValidationException` — carries the sanitized `errorCode`. Note: Apex does not allow a subclass of `Exception` to call `super(message)` explicitly (fails to compile with "Method is not visible: void System.ApexBaseException.<init>(String)"); the class instead exposes a static `of(errorCode, message)` factory that uses the compiler-generated `(String)` constructor and sets `errorCode` afterward.
- `MyBox_DocGenBoxAdapter` / `MyBox_DocGenBoxAdapterImpl` — the small package-call test seam mentioned in chunk 3, so tests substitute a stub `box.DocGenResponse`/exception instead of performing a real callout or mocking managed-package HTTP internals.
- Supporting metadata added so the Apex compiles/deploys: the seven Case fields, the `HR_DocGen_Schema__mdt`/`HR_DocGen_Field__mdt` Custom Metadata Types, the complete `newHire/1.0` field mapping (`Lifecycle_Status__c = Draft`, pending chunk 2's Box template IDs and chunk 6 activation — no template/folder IDs are set), and a `MyBox_HR_DocGen_Access` permission set granting FLS on the seven Case fields (required because `WITH SECURITY_ENFORCED` throws otherwise; deploying a field via Metadata API alone does not grant FLS to any profile).
- Verified directly against the installed package (`Box for Salesforce 5.56.0.1`) in the target dev org rather than assumed from public docs: `box.DocGenRequest`/`box.DocGenResponse`/`box.DocGenToolkit`/`box.Toolkit` method and property signatures used above. One correction to this document: `box.DocGenRequest` has no `input_source` property — only `file`, `file_version`, `destination_folder`, `output_type`, and `document_generation_data` (a `List` of one entry with `generated_file_name`/`user_input`); the toolkit apparently sets `input_source` internally.
- Test coverage: `MyBox_DocGenSchemaServiceTest` covers the full validator (missing required, unknown/duplicate/reserved/invalid-syntax paths, type mismatch, length, allowed-values, scalar/object path collision, payload-too-large, boolean-false-is-a-value, omit/emptyString blank handling) entirely against in-memory metadata, with no deployed-record dependency. `MyBox_GetCaseDocGenStatusTest` covers all documented status outcomes. `MyBox_SubmitTransientCaseDocGenTest` covers every Case/folder authorization guard.
- **Outstanding/blocked:** three `MyBox_SubmitTransientCaseDocGenTest` cases (the full success path, the Box-definite-rejection path, and the callout-exception path) exercise `loadActiveSchema`, which requires a deployed, Active schema record. Deploying *any* `CustomMetadata` record (including a disposable probe record with no relation to this feature) to the target dev org currently fails org-side with `UNKNOWN_EXCEPTION` from the Metadata API, while deploying the Custom Metadata Type definitions themselves succeeds — this reproduces even for a brand-new, unrelated custom metadata type, so it is a platform/org limitation, not a defect in these files. The `HR_DocGen_Schema.MyBox_Test_Harness_1_0` / `..._Tiny_1_0` / `..._Collision_1_0` records under `customMetadata/` are authored and ready to deploy once that is resolved (or created manually via Setup). Chunk 2/6 activation of the real `newHire/1.0` record is unaffected since it was always scheduled for chunk 6, not this pass.
- Not built in this pass (explicitly out of scope): the Screen Flows (chunks 4/7), the Box Doc Gen template (chunk 2), the `newHire/1.1` extension metadata (chunk 7), and Experience Cloud/permission wiring for end users (chunk 6). Per-field `Required__c`/`Max_Length__c` values for the real `newHire/1.0` mapping were deliberately left at generic defaults (`Required__c = false` except `submitter.attested`, `Blank_Behavior__c = omit`, no length caps) rather than invented business rules; the source-PDF-driven field checklist remains chunk 1's `docs/hr_request_demo_contract.md` deliverable.

### Experience user and folder access

The setup handoff must identify the exact Experience site, two synthetic test users, their licenses and Flow/Apex/Case permissions, the Case sharing mechanism, and how each user obtains access to the associated Box folder. Existing authenticated identity/audit records are permitted; never populate Case contact or employee fields from the form.

Verify the package's Experience App User behavior with the actual site runtime, service-account folder access, and any required record-folder permission mapping. Hiding Explorer actions is a UI setting, not an access-control guarantee. Confirm user A cannot view user B's Case/folder or submit to a substituted folder ID.

Preconfigure the demo users and sharing before the main demo; automatic user provisioning is not a feature to build here. Only assign rights needed by those users, and keep templates/root folders out of their browsing scope where the package permits.

## Focused Test Plan

Use synthetic inputs only. These checks support the demo requirements; no volume, scheduler, webhook, or production release-management suite is required.

| Area | Required evidence |
| --- | --- |
| Full form | Every source-form field appears in the checklist, Flow, mapping, and rendered PDF. Required fields, attestation, and known conditional rules behave correctly. Hidden stale values are excluded or blanked. |
| Mapping and value handling | Our Flow assignments and generic validator preserve field identity, zero, false, quotes, Unicode, newlines, and configured null/omit behavior. Test these application rules in the final implementation; no standalone Salesforce type-support or Box JSON-acceptance test. |
| Generic validation | Focused Apex tests cover missing required values; unknown/inactive/duplicate schema configuration; unknown/duplicate/colliding/reserved paths; wrong types; invalid allowed values; and field/payload limits. Use callout mocks/test seams appropriate to the package. |
| Schema flexibility | Full `1.0` works; `1.1` adds and renders `request.referenceNote` with no Apex changes. `1.0` rejects that extension. Existing Case schema pointers remain correct. |
| Transactions and provisioning | Live Experience execution crosses both callout boundaries without uncommitted-work errors. Exactly one Case folder/association is created; competing Case automation is excluded. |
| Content and status | PDF appears in the correct folder; supporting upload creates no Salesforce `ContentVersion`; manual refresh handles processing, generated, failed, missing-output, and unavailable-status cases. No raw response reaches Flow persistence or UI. |
| Failure recovery | Exercise a definite rejection, a mocked ambiguous submission, and a Case-update failure after acceptance. No automatic resubmission occurs; returned opaque IDs support manual recovery when available. Fault handling itself can exit safely if status DML fails. |
| Access | Actual Experience user A can submit, upload, preview, and refresh. User B cannot access A's Case/folder. Substituting another folder or Case ID is rejected. |
| Storage boundary | Check Cases, custom objects, Files, Notes, Tasks, events, async state, failed interviews, error emails, logs, and package diagnostics for synthetic marker values. No request-storage object is introduced. Record anything not observable rather than claiming a universal guarantee. |

Run Apex tests needed for the changed classes and the deployment target. For the form and managed UI Elements, use the actual Experience site to check our assembled workflow, authorization configuration, and template rendering. Documented platform capabilities are design inputs, not separate feasibility gates.

## Implementation Chunks for Agent Delegation

These are future implementation work packets, not authorization to implement or deploy as part of this document update. Each chunk has one owner, bounded outputs, and a completion gate. A coordinating agent integrates the results and keeps this plan/current handoff contracts consistent.

Before assigning a chunk, supply the target Salesforce alias/site, approved Box demo root, this plan, the source PDF, and completed predecessor handoffs. Each implementer must read applicable repository instructions and relevant Salesforce/Box skills. Use the existing dirty worktree carefully; do not overwrite another owner's files or retrieve broad unrelated metadata.

### Dependency and ownership map

| Chunk | Deliverable | Depends on | Primary ownership |
| --- | --- | --- | --- |
| 0 | Environment configuration readiness | None | Setup notes and non-secret configuration checklist; no new Apex or Flow |
| 1 | Field checklist, DTO contract, metadata foundations | None | Final DTO definition, Case fields, metadata types, `1.0` records |
| 2 | Full-form Box template | 1; Box access from 0 for publication | Box template and template manifest |
| 3 | Generic validator and submission action | 1 | Submission/validation Apex and focused tests |
| 4 | Complete intake Flow | 1 | Main intake Flow and mapping checklist results |
| 5 | Manual status action | 1 | Separate status Flow and optional status wrapper/tests |
| 6 | Experience integration and first end-to-end run | 0, 2, 3, 4, 5 | Site/page configuration, permissions, scoped provisioning exclusion |
| 7 | Schema-extension demonstration | 6 | `1.1` records, extension Flow copy, template extension |
| 8 | Acceptance verification and presenter runbook | 7 | Test evidence, recovery/reset and demo instructions |

Chunks 0 and 1 can start in parallel. Chunk 1 uses the documented types and does not wait for an environment experiment; records awaiting environment IDs remain Draft. Chunks 2–5 can proceed in parallel after chunk 1 freezes the interfaces; Box-side publication in chunk 2 requires the relevant access/configuration from chunk 0. Chunk 4 can build an inactive Flow against the agreed action contract; connecting/deploying its action reference waits for chunk 3. Chunk 6 owns shared-org integration and deployment ordering after those owners finish. Chunk 7 edits only extension artifacts and explicitly coordinated configuration values. Do not let multiple agents edit the same Flow, metadata record, or permission set concurrently.

### Chunk 0 — Prepare environment configuration

**Goal:** Prepare the target environment for the documented Salesforce and Box capabilities. This is a configuration task, not a development spike.

- Record the target org/site and package version; configure or confirm Doc Gen entitlement/enablement, service-account authorization, approved Box root access, and Box Experience settings.
- Record the runtime service identity, two synthetic Experience users, relevant permissions, environment IDs, and the Case/folder access arrangement.
- Link the documented folder, Doc Gen, and status action interfaces for the implementing agents. Do not create classes or Flows to demonstrate type support or arbitrary JSON acceptance.
- Locate competing Case-folder automation and document how the demo user will access the Case and Box folder.

**Deliverables:** `docs/hr_request_demo_environment.md` with configuration readiness, non-secret identifiers, documented interface links, and any outstanding setup items. No spike classes, throwaway Flow, or preliminary PDF is required.

**Done when:** Required environment configuration and access are ready for final integration. Report unresolved setup dependencies as outstanding; they block dependent Box publication or chunk 6 acceptance, but not independent source authoring. PDF generation, upload, preview, and transaction integration are checked with the final implementation in chunk 6.

### Chunk 1 — Freeze the full-form contract and metadata

**Goal:** Provide stable interfaces for independent form, template, and Apex work.

- Compare the source PDF with every row of the mapping and record labels, choices, requiredness, conditions, lengths, blank policy, and synthetic examples in `docs/hr_request_demo_contract.md`. Identify any unresolved sample-form details explicitly.
- Create the final `DocGenFieldValue` class directly using documented types and annotations; finalize submission/status inputs and outputs, status/error allow-lists, path rules, and typed `Allowed_Values__c` representation. No spike class precedes this work.
- Author the two metadata types, complete `newHire/1.0` field records, and seven Case fields. Keep environment-specific IDs separate from credentials. Records awaiting the final chunk 2 template IDs stay Draft; chunk 6 supplies those IDs and activates the configuration after validation, so metadata authoring does not depend on the completed template.
- Set attestation to required/true-only, compensation to text, reserved Case/schema roots, and Flow ownership of conditional rules and Case DML.

**Deliverables:** DTO source and metadata, Case fields, schema metadata, `1.0` records, and the contract checklist. Publish exact filenames for the next owners; no business payload object.

**Done when:** Every specified field has one agreed mapping, unknown form rules are resolved or clearly bounded for the demo, metadata is deployable, and downstream agents can implement without inventing contracts. Do not build the validator, final Flow, or second schema in this chunk.

### Chunk 2 — Author the complete Box template

**Goal:** Produce the PDF needed for the main demonstration.

- Build/register a Doc Gen template for the full `1.0` contract using the approved Box root.
- Include all mapped values, Case number, and schema identity; choose readable date/Boolean presentation and preserve multiline notes.
- Verify tags manually and render synthetic data, including blank optional fields.
- Publish template file/version IDs and folder-template ID in a manifest for the integration owner; do not edit shared schema records concurrently.

**Deliverables:** The Box template, `docs/hr_request_demo_template_manifest.md`, and a synthetic render with field-checklist results.

**Done when:** The full-form PDF renders correctly and the exact pinned template version is available to the configured runtime identity. No automated tag-activation service is required.

### Chunk 3 — Implement generic validation and submission

**Goal:** Submit any approved schema through the single transient interface.

- Implement metadata loading and generic validation/serialization, including reserved roots, duplicate/prefix collisions, typed values, blank policy, allow-lists, and bounds.
- Implement Case/schema/folder authorization checks and the basic existing-batch/state guard.
- Build the documented package request in the final `SubmitTransientCaseDocGen` action, submit synchronously, and normalize acceptance, definite rejection, and unknown outcome without Case DML.
- Add focused tests for the generic contract, authorization, request serialization, and normalized failure behavior. Use a small package-call adapter/test seam if needed; do not create a general integration framework.

**Deliverables:** Submission/validator Apex and corresponding tests, plus brief test results and any required class permissions.

**Done when:** The final classes compile against the package interface and focused tests establish our mapping/validation/error contract; the live end-to-end run follows in chunk 6. No New Hire field-specific logic, payload persistence, scheduler, or status UI is introduced.

### Chunk 4 — Build the full intake Flow

**Goal:** Implement every specified form field and its typed handoff.

- Build `HR_New_Hire_Intake` with standard components, section layout, the agreed choice lists, full validation, and true-only attestation.
- Implement generic Case creation and exact-schema configuration lookup, folder creation, both transaction boundaries, and section-based descriptor assignments.
- Invoke the submission action once; handle all relevant faults and save only approved orchestration outputs.
- Clear assignable sensitive state, disable Previous after submission, and provide the Box uploader, generic receipt, and Case link. Make uploads optional for completion while retaining the control.

**Deliverables:** Inactive Flow metadata and completed mapping checklist. Any required action reference waits for chunk 3 deployment.

**Done when:** Every field maps exactly once, conditional values are cleared correctly, both transaction settings are explicit, and success/failure paths meet the contract. No partial form, custom LWC, retry loop, or extra payload fields on Case.

### Chunk 5 — Build manual status refresh

**Goal:** Let the user confirm PDF generation during the demo without background polling.

- Select and implement `HR_Check_DocGen_Status` using the documented managed action interface or a thin wrapper where needed to enforce the non-sensitive output contract. No preliminary capability experiment is required.
- Accept an authorized Case ID, resolve the stored batch ID server-side, normalize the single-job result, and let Flow write only status/output ID/error code.
- Handle processing, failed, generated, missing-output, missing-batch, and unavailable-status outcomes; preserve terminal state and avoid classifying a status-call failure as a failed generation.
- Return explicit next-step messaging and no raw Box result/error fields.

**Deliverables:** Separate status Flow, optional `GetCaseDocGenStatus` class/tests, and required permissions.

**Done when:** Manual checks work for the supported states and use only orchestration identifiers. No scheduler, polling counter, timed loop, webhook, or resubmit action is added.

### Chunk 6 — Integrate Experience Cloud and run the main workflow

**Goal:** Join the completed components into one working user journey.

- Apply verified environment/template IDs, deploy foundations and Apex before dependent Flows, and configure the actual Experience page and receipt navigation.
- Configure scoped Flow/Apex/Case permissions and the chosen Case/Box access mechanism for two synthetic users.
- Apply the intake exclusion to the verified existing folder-provisioning automation before activating the intake Flow.
- Add the managed uploader/explorer with requested preview/upload/download settings and disabled delete/rename/share/folder-creation controls.
- Run the full form as user A, generate the PDF, upload a supporting file, and refresh status. Check user B isolation and substituted folder/Case rejection.

**Deliverables:** Scoped site/page/permission/automation changes and `docs/hr_request_demo_integration_results.md` with non-sensitive IDs and outcomes only.

**Done when:** One complete submission works through the real Experience site with one Case/folder, the PDF and upload are accessible to the intended user, and cross-user checks pass.

### Chunk 7 — Prove schema flexibility without Apex changes

**Goal:** Demonstrate the reusable contract while preserving the specified form.

- Add `newHire/1.1` metadata with optional text field `request.referenceNote`.
- Copy the complete intake Flow to `HR_New_Hire_Intake_Schema_Demo`; change the pinned schema version and add only the extension field/mapping.
- Publish a matching template version and clearly labeled second demo launcher.
- Run both configurations using the same Apex build; show `1.0` rejects the extension while `1.1` renders it.

**Deliverables:** Extension metadata, Flow copy, template manifest update, and before/after demonstration evidence.

**Done when:** The extension appears in the generated PDF, the original full form still works, and there is no Apex source change between the two demonstrations. A second complete business process and automated schema release tooling are out of scope.

### Chunk 8 — Verify acceptance and prepare the presenter

**Goal:** Make the completed demo repeatable and its limits clear.

- Run the focused test plan, necessary Apex/deployment checks, and both full live journeys. Record passed, failed, and unobservable checks separately.
- Exercise safe synthetic failure cases and inspect Salesforce storage/diagnostics for marker values; do not retain payload-bearing diagnostic exports.
- Write `docs/hr_request_demo_runbook.md` with launch links, synthetic input instructions, expected PDF/status, schema-extension steps, and manual recovery for rejection, uncertain acceptance, or Case-update failure.
- Include a pre-demo setup check and a reset procedure restricted to explicitly identified demo Cases/folders. Reset must account for uncertain Box jobs and avoid deleting shared roots/templates or unrelated records.
- Record the supported user/site/package/configuration and deferred production capabilities.

**Deliverables:** Acceptance results and presenter/recovery/reset runbook, with only non-sensitive identifiers or approved synthetic examples outside configuration metadata.

**Done when:** A presenter can run both demonstrations and one sanitized failure without developer intervention, and the report accurately distinguishes tested application behavior from unverified platform guarantees.

### Required handoff from every implementation agent

Provide: files/artifacts changed; concrete checks and outcomes; non-secret configuration dependencies; unresolved issues; and the next chunk that can proceed. Do not return request payloads, credentials, raw error responses, or unredacted diagnostic dumps. A chunk is complete only when its stated acceptance gate is met; report a failed prerequisite rather than broadening scope.

## Assumptions and Prerequisites

- Documented Salesforce type support and Box JSON submission are accepted design capabilities. The remaining readiness work concerns target-org/Box configuration; compilation and tests concern the final implementation. No feasibility spike is required.
- Only synthetic HR data/documents are used. Existing authenticated-user audit identifiers and non-sensitive orchestration IDs are permitted. Real HR data and production privacy approval are deferred.
- Active, non-paused Flow processing is accepted for the POC, subject to the stated failed-interview and diagnostic limitations. No Pause, Wait, save-for-later, or payload-bearing asynchronous work.
- Box Doc Gen entitlement/enablement and required authorization scopes are confirmed before implementation. Box describes enablement and reauthorization in [Doc Gen setup](https://support.box.com/hc/en-us/articles/48670280271635-Setting-up-Box-Doc-Gen-in-Salesforce).
- Server operations use the verified configured Box service identity; no shared links are created. Verify the actual package identity behavior rather than assuming all actions default to the service account.
- Experience users are authenticated and use the package's Box App User integration. Confirm the Client Credentials Grant app, App + Enterprise access, scopes, CORS, service-account ownership/co-ownership, and `Box App User (Experience Cloud)` permissions using [Box Experience Cloud setup](https://support.box.com/hc/en-us/articles/26032384109075-Setting-up-Box-UI-Elements-in-Experience-Cloud).
- The selected Experience runtime supports the installed managed components and required CSP/framing settings. No portal migration or custom uploader is assumed.
- Template and folder IDs are environment-specific configuration; credentials and request values never belong in Custom Metadata. Keep matching schema/Flow/template versions explicit.
- Salesforce stores only the generic Case, approved orchestration fields, and package associations. Box holds submitted Doc Gen input, generated PDFs, and supporting documents under its configured access/retention policies; broader retention/legal review precedes any real-data use.
- The full specified form and metadata flexibility remain mandatory. Additional forms require admin-maintained Flow/template mappings but reuse the unchanged submission service.
