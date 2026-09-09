# HR Request Demo — Box Doc Gen Template Manifest (`newHire/1.0`)

Chunk 2 template is **published and operator-tested**. `HR_DocGen_Schema.NewHire_1_0` is **Active** after chunk 6 wiring (folder-Flow exclusion, Experience permissions, schema IDs).

Synthetic HR data only. This file must never contain live request payloads.

## Generation API

Document generation uses Box Doc Gen API version `2025.0`:

`POST https://api.box.com/2.0/docgen_batches`

Required header: `box-version: 2025.0`.

Salesforce runtime calls the same operation through `box.DocGenToolkit.submitDocGenBatch`. Do not use record-based Box Doc Gen (`box__DocGen_Template__c` / Case-field merge).

The merge payload is `document_generation_data[].user_input`. Canonical synthetic `user_input`: [examples/newHire_1_0_user_input.json](examples/newHire_1_0_user_input.json). Field contract: [hr_request_demo_contract.md](hr_request_demo_contract.md).

## Template publication

Recorded **9 Sep 2026**. Operator created the Word template from the example JSON and confirmed generation. CLI actor `35570754363` (`jkoepp+admin@boxdemo.com`) verified the **file** (the prior ID `456566806586` was a typo).

| Item | Value |
| --- | --- |
| Box file ID | `2456566806586` |
| Box file version ID | `2724134783386` |
| File name | `new_hire_box_docgen.docx` |
| Parent folder | `389691397233` (`Box Doc Gen Templates`) under approved root `372250559857` (`Salesforce and AgenForce Root`) |
| Size / modified | 39347 bytes; `2026-09-09T10:35:43-07:00` |
| Marked as Doc Gen template | Operator-tested generation. `GET /2.0/docgen_templates` and `GET /2.0/docgen_templates/2456566806586` (and `/tags`) still HTTP 404 for this OAuth CLI app (`box-version: 2025.0`) |
| Operator generation test | **Passed** (synthetic `user_input`, 9 Sep 2026) |
| CLI file read | `GET /2.0/files/2456566806586` **OK** as `35570754363` |
| Runtime identity that must generate | Toolkit **service account** (not assumed to be this CLI user) |
| Output type | `pdf` |
| Output file name pattern | `HR Request - {caseNumber}` |
| Salesforce schema record | `HR_DocGen_Schema.NewHire_1_0` is **Active**. File `2456566806586`, version `2724134783386`. |

## Word tags (`{{json.path}}`)

Box Doc Gen tags use nested JSON paths with no spaces or hyphens in key names. Optional omitted keys should not leave a visible `{{tag}}` in the PDF — mark those tags `optional` where the add-in/script supports it.

| JSON path | Value type | Suggested Word tag | Notes |
| --- | --- | --- | --- |
| `schema.key` | text (server) | `{{schema.key}}` | Always `newHire` for this version |
| `schema.version` | text (server) | `{{schema.version}}` | Always `1.0` |
| `case.id` | text (server) | `{{case.id}}` | Opaque Salesforce Id |
| `case.caseNumber` | text (server) | `{{case.caseNumber}}` | Also used in the generated filename |
| `request.requestDate` | date | `{{request.requestDate :: format("mm-dd-yyyy")}}` | JSON is `YYYY-MM-DD` |
| `request.notificationType` | text | `{{request.notificationType}}` | Allowed: `newHireRehire` |
| `employee.employeeId` | text | `{{employee.employeeId :: optional}}` | |
| `employee.firstName` | text | `{{employee.firstName}}` | Required |
| `employee.lastName` | text | `{{employee.lastName}}` | Required |
| `assignment.region` | text | `{{assignment.region}}` | Required |
| `assignment.district` | text | `{{assignment.district}}` | Required |
| `assignment.station` | text | `{{assignment.station}}` | Required |
| `assignment.startDate` | date | `{{assignment.startDate :: format("mm-dd-yyyy") :: optional}}` | |
| `assignment.isRehire` | boolean | See boolean presentation | JSON `false` is a value, not blank |
| `assignment.primaryTitle` | text | `{{assignment.primaryTitle}}` | Required |
| `assignment.isDualRole` | boolean | See boolean presentation | |
| `assignment.department` | text | `{{assignment.department :: optional}}` | |
| `assignment.status` | text | `{{assignment.status :: optional}}` | |
| `assignment.manager` | text | `{{assignment.manager}}` | Required |
| `assignment.employmentStatus` | text | `{{assignment.employmentStatus :: optional}}` | |
| `certification.level` | text | `{{certification.level :: optional}}` | |
| `certification.txdshsNumber` | text | `{{certification.txdshsNumber :: optional}}` | |
| `certification.priorStateDetails` | text | `{{certification.priorStateDetails :: optional}}` | Omitted when blank |
| `compensation.currentHourlyOrSalary` | text | `{{compensation.currentHourlyOrSalary :: optional}}` | |
| `compensation.rateReason` | text | `{{compensation.rateReason :: optional}}` | Present when compensation is Above minimum / Above maximum |
| `notes` | text | `{{notes :: optional}}` | Preserve line breaks |
| `submitter.name` | text | `{{submitter.name}}` | Required |
| `submitter.jobTitle` | text | `{{submitter.jobTitle}}` | Required |
| `submitter.email` | text | `{{submitter.email}}` | Required |
| `submitter.attested` | boolean | See boolean presentation | Always `true` on a valid submit |

### Boolean presentation

JSON sends real booleans. Operator generation succeeded; the exact Yes/No condition syntax used in the Word file was not recorded here. If a later template edit is needed, prefer readable Yes/No rather than `true`/`false`, and re-test with the synthetic payload.

## Remaining verification (chunk 6 / service account)

1. Toolkit **service account** `49821057233` can `GET` file `2456566806586` and complete `POST /2.0/docgen_batches` (batch `dfadffe5-250e-43d9-a0ab-beb8dcbb5f5b`, output `2456627065285`). This CLI OAuth app can read the file but still gets HTTP 404 on Doc Gen template REST (`GET /2.0/docgen_templates`).
2. Optional: `GET /2.0/docgen_templates/2456566806586/tags?template_version_id=2724134783386` with `box-version: 2025.0` as the service identity. A tag list does not prove type compatibility.
3. Second render that omits `certification.priorStateDetails` and `compensation.rateReason` if that was not part of the operator test. The service-account smoke used the full synthetic payload.
4. First live Experience render as user A remains.
