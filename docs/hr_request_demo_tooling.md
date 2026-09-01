# Salesforce Case Intake and Box Doc Gen

## Summary

Build an authenticated Experience Cloud Screen Flow for the New Hire/Rehire intake represented in `/Users/jkoepp/Downloads/New Hire Smartsheet AMH 8.18.pdf`. The Flow will create a Case and related submission record, synchronously create the Case's Box folder, submit an asynchronous PDF Doc Gen job using the complete JSON payload, then present the Box uploader.

The design uses Box for Salesforce 5.53 already installed in the org. Box's native record-based Doc Gen action will not be used because the complete payload is not on Case. A schema-neutral Apex service will instead call `box.DocGenToolkit.submitDocGenBatch`, which supports arbitrary JSON input through the [Box Doc Gen batch API](https://developer.box.com/guides/docgen/generate-document).

## Implementation Changes

### End-to-end Flow

1. Add a New Hire/Rehire Screen Flow to Experience Cloud with standard components covering:
   - Employee ID, legal first/last name, submission date.
   - Region, district, station, start date, rehire status, title, dual role, department, manager, employment status.
   - Certification details, compensation category/reason, notes.
   - Submitter name, title, email, and required attestation.
2. Limit v1 to New Hire/Rehire. Other notification types become separate future flows and payload schemas.
3. On submit:
   - Create a Case with `Subject = New Hire - {First} {Last}`, the Experience user's Contact/Account, New status, Experience Cloud origin, and an intake-managed provisioning flag.
   - Build the versioned JSON payload through generic Apex and create `Case_Intake_Submission__c`.
   - Call `box__CreateFolderForRecordIdFromTemplate_v2`, using the Case ID and configured folder-template ID.
   - Configure the folder action to start a new Flow transaction so the Case is committed before the Box callout, as supported by [Salesforce Flow transaction control](https://help.salesforce.com/s/articleView?id=flow_concepts_transaction.htm&language=en_US).
   - Submit the JSON payload to Box Doc Gen as a PDF and record the returned batch ID.
4. Show the managed Box Content Uploader on the next Flow screen with the returned folder ID. Files go directly to Box; no Salesforce Files staging or duplicate retention is introduced.
5. Show a receipt containing the Case number, submission reference, folder status, and Doc Gen status. "Submitted" is sufficient because rendering remains asynchronous.
6. Add Box Content Explorer to the Experience Cloud Case page with preview, upload, and download enabled; disable delete, rename, share, and folder creation. The supported component properties are documented in [Box UI Elements for Salesforce](https://developer.box.com/guides/tooling/salesforce-toolkit/ui-elements).

### Declarative versus custom work

| Capability | Implementation |
| --- | --- |
| Form screens, validation, Case creation, routing | Screen Flow and Salesforce metadata |
| Case Box folder creation | Existing Box managed-package Flow action |
| Direct supporting-document upload | Managed Box Content Uploader |
| Case folder browsing | Managed Box Content Explorer |
| Full versioned JSON construction | Custom, schema-neutral Apex |
| Arbitrary-payload Doc Gen submission | Custom Apex wrapper around `box.DocGenToolkit` |
| Doc Gen completion polling and retries | Custom scheduled Apex |
| Dynamic form rendering | Not in v1; separate standard Screen Flows reuse the same Apex services |

Modify the existing `Create_Box_Folder_for_New_Case` record-triggered Flow to exclude Cases marked as intake-managed, preventing it from racing with the synchronous folder creation in this Screen Flow.

## Interfaces and Data Model

### `Case_Intake_Submission__c`

Create a Case-controlled child record with:

- Case relationship, schema key/version, payload JSON, processing status, retry count, and last error.
- Selected reportable fields: employee ID, first/last name, start date, region, district, station, primary title, employment status, submitter identity/email, and submitted timestamp.
- Box folder ID, Doc Gen batch ID/status, generated file ID/version, and completion timestamp.
- Status lifecycle: `Created`, `Folder Ready`, `Doc Gen Submitted`, `Completed`, `Folder Failed`, `Doc Gen Failed`, `Timed Out`.

Use private/parent-controlled sharing and restricted field-level access because the payload includes HR, certification, and compensation information.

### Schema configuration

Create custom metadata for each payload schema:

- Schema key and version.
- Active flag.
- Box folder-template ID.
- Doc Gen template file ID and optional version ID.
- Output type, fixed to PDF for this schema.
- Filename pattern: `New Hire - {lastName}, {firstName} - {caseNumber}`.
- Allowed JSON paths, data types, requiredness, maximum lengths, and blank-value behavior.

The generic JSON contract uses stable lower-camel-case paths such as:

```json
{
  "schema": {"key": "newHire", "version": "1.0"},
  "case": {"id": "...", "caseNumber": "..."},
  "employee": {"id": "...", "firstName": "...", "lastName": "..."},
  "assignment": {"region": "...", "district": "...", "station": "..."},
  "certification": {},
  "compensation": {},
  "submitter": {},
  "notes": ""
}
```

Dates serialize as `YYYY-MM-DD`, booleans as JSON booleans, and numbers as JSON numbers. Empty text becomes `""`; absent dates and numbers become `null`.

### Apex contracts

- `BuildDocGenPayload` accepts schema key/version plus a collection of `{path, valueType, value}` entries. It validates paths against custom metadata, safely constructs nested objects, and returns serialized JSON.
- `SubmitCaseDocGen` accepts the submission ID and Box folder ID, loads the configured template, deserializes the saved payload, calls `box.DocGenToolkit.submitDocGenBatch`, and returns/stores the batch ID.
- `DocGenStatusPoller` runs every five minutes, checks pending batches with `getDocGenBatch`, and records the generated file ID or terminal failure. Stop after 12 unsuccessful checks and mark the submission `Timed Out`.
- All services run `with sharing`, reject inactive/unknown schemas, enforce payload-size limits, sanitize generated filenames, and avoid logging payload contents.

## Test Plan

- Validate every sample field, required-field rule, conditional section, attestation, and special characters/newlines in JSON.
- Test two distinct schema configurations without changing Apex to prove schema neutrality.
- Verify Case and child-record mappings, JSON types, null handling, template-tag coverage, and PDF filename.
- Confirm folder creation returns the Box folder ID before the upload screen and creates only one Case-folder association.
- Verify Doc Gen submission, polling, successful PDF appearance, transient retry, permanent failure, timeout, and duplicate-submit protection.
- Verify direct uploads create Box files without creating Salesforce `ContentVersion` records.
- Test Experience users A and B cannot access each other's Cases or Box folders.
- Confirm Explorer permits preview/upload/download but blocks delete, rename, share, and folder creation.
- Test expired Box authorization, inaccessible template, missing folder-template configuration, Box 403/409/429 responses, and unavailable Doc Gen.
- Deploy inactive to a sandbox-specific Box root, run end-to-end tests, then activate the Flow and monitor failed submission statuses.

## Assumptions and Prerequisites

- Server operations run as the configured Box for Salesforce service account; no shared links are created.
- Experience users are authenticated Box App Users, not guests.
- Configure a Box Client Credentials Grant app, App + Enterprise access, required scopes/CORS entries, service-account ownership or co-ownership, and the `Box App User (Experience Cloud)` permission set according to [Box's Experience Cloud setup](https://support.box.com/hc/en-us/articles/26032384109075-Setting-up-Box-UI-Elements-in-Experience-Cloud).
- The Experience Cloud CSP and framing changes required by Box receive security approval before production.
- Each future form schema gets its own admin-maintained Screen Flow and custom-metadata configuration; the Apex payload and Doc Gen services remain unchanged.
- No automatic Salesforce retention purge is needed because supporting documents upload directly to Box. The JSON submission remains in Salesforce until an organizational HR retention policy is supplied.
