# HR Request Demo — newHire/1.0 Field Contract

Source: `artifacts/new_hire_smartsheet.pdf` (Allegiance Mobile Health Smartsheet form, 6 pages, captured 18 Aug 2026). Compared to the mapping in [hr_request_demo_tooling.md](hr_request_demo_tooling.md). Dropdown option lists are **not visible** in the static PDF; demo choice lists below are bounded for the POC and labeled as such.

Do not invent production HR rules. Flow owns form-specific conditions. Apex owns unconditional requiredness, allow-lists, blanks, and size limits.

## Ownership

| Concern | Owner |
| --- | --- |
| Screen labels, visibility, conditional requiredness, clearing hidden values | Intake Flow |
| Exact path/type, `Required__c`, `Allowed_Values__c`, `Blank_Behavior__c`, `Max_Length__c` | `HR_DocGen_Field__mdt` + `MyBox_DocGenSchemaService` |
| Case DML | Intake / status Flows only |
| Nested JSON | Apex heap only |
| Supporting files | Box uploader after folder creation; not in `colDocGenFields` |
| “Send me a copy of my responses” | Out of scope |

## Page 1 of the PDF (not mapped)

The first page is a manager SOP (Applicant Pro, DSHS, UKG Pro, drug screen, photo, PCN). Those steps are **not** Screen Flow fields. Supporting documents that the SOP would attach are demonstrated later with a synthetic Box upload.

## Unresolved source-form details

1. **Closed dropdowns** — Rehire, Primary Title, Department, New Status, Full Time/PRN, Cert Level, and Current Hourly/Salary show as dropdowns with no option list in the PDF. Demo lists below are **POC bounds**, not extracted source values.
2. **Rehire control vs boolean path** — Source is a dropdown; contract path `assignment.isRehire` is boolean. Flow uses a checkbox. `false` is a value, not blank.
3. **Current Hourly/Salary** — Source is a dropdown, stored as **text** (`compensation.currentHourlyOrSalary`). Demo values are inferred from the rate-reason help text (“above minimum” / “above maximum”), not from a visible picklist.
4. **New Status vs Full Time/PRN** — Two separate source fields. Mapped to `assignment.status` and `assignment.employmentStatus`. Meaning of “New Status” is not defined in the PDF.
5. **Field lengths** — Not specified. Demo `Max_Length__c` values below are POC caps, not business rules.
6. **Notification Type** — Source offers five checkboxes; v1 implements only **New Hire / Rehire**. Other types are a different Flow later. Flow constant `newHireRehire`.
7. **Today’s Date** — Source is a date picker. Flow uses `$Flow.CurrentDate` as `request.requestDate`; the user does not enter it.
8. **Region / District / Station “Enter NA if no changes”** — Relevant to change-of-status, not new hire. v1 still requires these three fields (PDF asterisks). Synthetic data uses real-looking values, not `NA`.
9. **Rate reason** — “If above minimum, comment is required. If above maximum, approval documentation is required… attach under Part Three.” Metadata keeps the path optional; Flow requires `inRateReason` when compensation is `Above minimum` or `Above maximum`. Attachment for “above maximum” is the optional Box upload, not a Salesforce file.
10. **Prior cert help text** — Asks for backup documentation to an HR mailbox. Demo: optional text plus optional Box upload. No Salesforce email of form contents.

## Demo choice lists (POC bounds)

Use these exact strings in Flow picklists and, where noted, in `Allowed_Values__c`.

| Path | Demo allowed values |
| --- | --- |
| `request.notificationType` | `newHireRehire` |
| `assignment.primaryTitle` | `EMT-Basic`, `EMT-Advanced`, `Paramedic`, `Licensed Paramedic`, `Dispatcher`, `Supervisor`, `Other` |
| `assignment.department` | `Operations`, `Clinical`, `Fleet`, `Corporate`, `Other` |
| `assignment.status` | `New Hire`, `Rehire`, `Transfer`, `Promotion` |
| `assignment.employmentStatus` | `Full Time`, `PRN` |
| `certification.level` | `EMT-Basic`, `EMT-Advanced`, `EMT-Paramedic`, `Licensed Paramedic`, `CCP`, `FP-C`, `None` |
| `compensation.currentHourlyOrSalary` | `At minimum`, `Above minimum`, `Above maximum` |
| `submitter.attested` | `true` only |

## Field checklist

Blank policy: required fields have no successful blank; optional blanks use `omit`. Boolean `false` and numeric zero are values.

Synthetic examples are fake and for demo/tests only.

| Source label | PDF required | Visibility / condition | Flow API name | Path | Type | CMDT required | Max length | Allowed values | Blank | Synthetic example | CMDT file |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Employee ID # | No | Always | `inEmployeeId` | `employee.employeeId` | text | No | 40 | — | omit | `E-10042` | `HR_DocGen_Field.NewHire_1_0_employee_employeeId` |
| Employee First Name (legal name) | Yes | Always | `inEmployeeFirstName` | `employee.firstName` | text | Yes | 80 | — | omit | `Jordan` | `HR_DocGen_Field.NewHire_1_0_employee_firstName` |
| Employee Last Name | Yes | Always | `inEmployeeLastName` | `employee.lastName` | text | Yes | 80 | — | omit | `Rivera` | `HR_DocGen_Field.NewHire_1_0_employee_lastName` |
| Today's Date | No picker in v1 | Formula | (formula `$Flow.CurrentDate`) | `request.requestDate` | date | Yes | — | — | n/a | interview date | `HR_DocGen_Field.NewHire_1_0_request_requestDate` |
| Notification Type | Yes | v1 constant only | `cNotificationType` = `newHireRehire` | `request.notificationType` | text | Yes | 40 | `["newHireRehire"]` | n/a | `newHireRehire` | `HR_DocGen_Field.NewHire_1_0_request_notificationType` |
| New Region | Yes | Always (v1) | `inRegion` | `assignment.region` | text | Yes | 80 | — | omit | `Central` | `HR_DocGen_Field.NewHire_1_0_assignment_region` |
| New District | Yes | Always (v1) | `inDistrict` | `assignment.district` | text | Yes | 80 | — | omit | `District 4` | `HR_DocGen_Field.NewHire_1_0_assignment_district` |
| New Station / Corporate Location | Yes | Always (v1) | `inStation` | `assignment.station` | text | Yes | 80 | — | omit | `Station 12` | `HR_DocGen_Field.NewHire_1_0_assignment_station` |
| Hire Date / Start Date | No asterisk | Always; help text says notify HR if it changes | `inStartDate` | `assignment.startDate` | date | No | — | — | omit | `2026-10-05` | `HR_DocGen_Field.NewHire_1_0_assignment_startDate` |
| Rehire? | No | Always; source dropdown → checkbox | `inIsRehire` | `assignment.isRehire` | boolean | No | — | — | omit | `false` | `HR_DocGen_Field.NewHire_1_0_assignment_isRehire` |
| New Primary Title | Yes | Always | `inPrimaryTitle` | `assignment.primaryTitle` | text | Yes | 80 | demo title list | omit | `Paramedic` | `HR_DocGen_Field.NewHire_1_0_assignment_primaryTitle` |
| Dual role? | No | Checkbox | `inIsDualRole` | `assignment.isDualRole` | boolean | No | — | — | omit | `false` | `HR_DocGen_Field.NewHire_1_0_assignment_isDualRole` |
| New Department | No | Always | `inDepartment` | `assignment.department` | text | No | 80 | demo dept list | omit | `Operations` | `HR_DocGen_Field.NewHire_1_0_assignment_department` |
| New Status | No | Always | `inNewStatus` | `assignment.status` | text | No | 80 | demo status list | omit | `New Hire` | `HR_DocGen_Field.NewHire_1_0_assignment_status` |
| New Manager | Yes | Always; “Enter NA if no changes” ignored for v1 new hire | `inManager` | `assignment.manager` | text | Yes | 80 | — | omit | `Alex Morgan` | `HR_DocGen_Field.NewHire_1_0_assignment_manager` |
| Status (Full Time / PRN) | No | Always | `inEmploymentStatus` | `assignment.employmentStatus` | text | No | 40 | `["Full Time","PRN"]` | omit | `Full Time` | `HR_DocGen_Field.NewHire_1_0_assignment_employmentStatus` |
| Cert Level | No | Always | `inCertificationLevel` | `certification.level` | text | No | 80 | demo cert list | omit | `EMT-Paramedic` | `HR_DocGen_Field.NewHire_1_0_certification_level` |
| TXDSHS Cert # | No | Always | `inTxdshsCertificationNumber` | `certification.txdshsNumber` | text | No | 40 | — | omit | `TX-88421` | `HR_DocGen_Field.NewHire_1_0_certification_txdshsNumber` |
| Prior Cert # State | No | Always; optional backup via Box | `inPriorCertificationDetails` | `certification.priorStateDetails` | text | No | 255 | — | omit | omit unless demoing optional text | `HR_DocGen_Field.NewHire_1_0_cert_priorStateDetails` |
| Current Hourly / Salary | No | Always | `inCurrentCompensation` | `compensation.currentHourlyOrSalary` | text | No | 40 | demo comp list | omit | `At minimum` | `HR_DocGen_Field.NewHire_1_0_comp_currentHourlyOrSalary` |
| New Hire Rate Reason | Conditional | Flow: required when compensation is Above minimum or Above maximum | `inRateReason` | `compensation.rateReason` | text | No | 255 | — | omit | `Market adjustment` when demonstrating the conditional | `HR_DocGen_Field.NewHire_1_0_compensation_rateReason` |
| Notes | No | Always | `inNotes` | `notes` | text | No | 2000 | — | omit | `Synthetic demo notes.` | `HR_DocGen_Field.NewHire_1_0_notes` |
| Person Completing Form | Yes | Always | `inSubmitterName` | `submitter.name` | text | Yes | 80 | — | omit | `Sam Patel` | `HR_DocGen_Field.NewHire_1_0_submitter_name` |
| Person Completing Form Job Title | Yes | Always | `inSubmitterJobTitle` | `submitter.jobTitle` | text | Yes | 80 | — | omit | `Operations Supervisor` | `HR_DocGen_Field.NewHire_1_0_submitter_jobTitle` |
| Person Completing Form Email | Yes | Always | `inSubmitterEmail` | `submitter.email` | text | Yes | 80 | — | omit | `sam.patel@example.test` | `HR_DocGen_Field.NewHire_1_0_submitter_email` |
| Accuracy / authorization attestation | Yes | Must be checked; Submit disabled until checked on source | `inAttestation` | `submitter.attested` | boolean | Yes | — | `[true]` | n/a | `true` | `HR_DocGen_Field.NewHire_1_0_submitter_attested` |

### Not in the collection

| Source control | Handling |
| --- | --- |
| Part Three file upload | Optional Box Content Uploader after folder creation. One successful synthetic upload for the presenter. |
| Send me a copy of my responses | Omitted. |

## Server-generated JSON roots (not Flow-supplied)

Apex adds `schema.key`, `schema.version`, `case.id`, and `case.caseNumber`. Flow must not send paths under `schema` or `case`.

## Apex / Flow contracts (frozen)

DTO: `force-app/main/default/classes/MyBox_DocGenFieldValue.cls` — `path`, `valueType`, `textValue`, `dateValue`, `numberValue`, `booleanValue`. No getters. Accessible no-arg constructor.

Submission: `MyBox_SubmitTransientCaseDocGen` — inputs `caseId`, `boxFolderId`, `schemaKey`, `schemaVersion`, `fieldValues`; outputs `batchId`, `status`, `errorCode`. No Case DML.

Status: `MyBox_GetCaseDocGenStatus` — input `caseId`; outputs `status`, `outputFileId`, `errorCode`. Null `status` means preserve prior Case status.

Schema selectors for the primary Flow: constants `cSchemaKey` = `newHire`, `cSchemaVersion` = `1.0`. Schema record `HR_DocGen_Schema.NewHire_1_0` stays **Draft** until chunk 6 writes Box template IDs.

### Integration status allow-list

`Case Created`, `Doc Gen Submitted`, `Doc Gen Processing`, `Document Generated`, `Folder Failed`, `Doc Gen Submit Failed`, `Submission Unknown`, `Doc Gen Failed`.

### Sanitized error codes (non-exhaustive, no payload text)

`REQUEST_INCOMPLETE`, `CASE_NOT_FOUND`, `SCHEMA_UNKNOWN_OR_INACTIVE`, `SCHEMA_CONFIG_INVALID`, `UNKNOWN_PATH`, `RESERVED_PATH`, `INVALID_PATH_SYNTAX`, `DUPLICATE_PATH`, `TYPE_MISMATCH`, `REQUIRED_BLANK`, `VALUE_NOT_ALLOWED`, `VALUE_TOO_LONG`, `PAYLOAD_TOO_LARGE`, `DOCGEN_REJECTED`, `DOCGEN_SUBMIT_UNKNOWN`, `NO_BATCH_ID`, `DOCGEN_OUTPUT_MISSING`, `DOCGEN_FAILED`, `DOCGEN_STATUS_UNAVAILABLE`, `CASE_UPDATE_FAILED`.

Numeric JSON is proven in harness tests (`compensation.rateAmount` on the test schema), not on the specified form.

## Downstream filenames

| Artifact | Path |
| --- | --- |
| Schema 1.0 | `force-app/main/default/customMetadata/HR_DocGen_Schema.NewHire_1_0.md-meta.xml` |
| Field records | `force-app/main/default/customMetadata/HR_DocGen_Field.NewHire_1_0_*.md-meta.xml` (26) |
| DTO | `force-app/main/default/classes/MyBox_DocGenFieldValue.cls` |
| Submission | `force-app/main/default/classes/MyBox_SubmitTransientCaseDocGen.cls` |
| Status | `force-app/main/default/classes/MyBox_GetCaseDocGenStatus.cls` |
| Types | `force-app/main/default/objects/HR_DocGen_Schema__mdt/`, `HR_DocGen_Field__mdt/` |
| Case fields | `force-app/main/default/objects/Case/fields/HR_*` and `Box_DocGen_*` |

Draft Flows `HR_New_Hire_Intake` and `HR_Check_DocGen_Status` implement this checklist in org/source (see [hr_request_demo_status.md](hr_request_demo_status.md)). Chunk 2 tags the Box template with these paths plus `schema.*` and `case.*`.
