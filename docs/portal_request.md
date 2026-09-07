# Portal Request — Case Creation Flow

## Purpose and scope

Add a simple **Submit a Case** Screen Flow to the existing **Default** Experience Cloud site. Every authenticated user whose profile permits login to that site must be able to submit, including internal Salesforce users. Do not require an external-user type, a Contact record, or membership in a separate requester group.

The requested sequence is:

1. Collect basic Case information.
2. Create a Case with the **Portal Request** record type.
3. Use a Box Flow Action to create and associate the Case folder.
4. Use a Box Flow Action to grant the submitting user **EDITOR** access to that folder.
5. Show the Box File Upload UI Element so the user can upload one or more files into the new folder.

This document is an implementation design; it does not represent deployed metadata or verified org configuration. Proposed Flow API name: `Portal_Create_Case`. This is a general Case intake flow, separate from the sensitive HR intake in [hr_request_demo_tooling.md](hr_request_demo_tooling.md). Subject and Description are intentionally stored on the Case. Doc Gen, HR schema metadata, and Case Team Assignment records are outside this flow.

The org already has Case-creation-triggered automation. Reserve that automation for Cases created through the internal Case intake path. A Case submitted through `Default` is a **Portal Request**, even when its submitter is an internal Salesforce user; it must bypass the existing internal creation automation.

## Portal Request record type and support process

Define the following Case configuration explicitly:

| Configuration | Definition |
| --- | --- |
| Case record type | Label **Portal Request**, developer name `Portal_Request`, active. |
| Related Support Process | Name **Portal Request Support**, active; create it specifically for this record type. |
| Available statuses | **New**, **Working**, **Closed**. |
| Default status | **New**. |
| Closed status | **Closed**, using a Case Status value marked as closed. **New** and **Working** remain open statuses. |

Create the Support Process first, then associate the Portal Request record type with it. Reuse the org's equivalent existing Case Status values and verify their API values; add a missing value only when necessary. Keep the process limited to these three statuses. Salesforce documents the support-process and record-type relationship in [Create Support Processes](https://trailhead.salesforce.com/content/learn/projects/create-a-process-for-managing-support-cases/create-support-processes).

The lifecycle is **New → Working → Closed**: intake creates a New Case, a support agent marks it Working when handling begins, and the agent closes it when resolved. The Support Process defines available statuses; it does not automatically advance them or enforce that transition order. Folder creation and file uploads do not change Case Status.

Make this record type available to every eligible portal-member profile, including internal profiles, and to support staff handling these Cases. Assign an appropriate Case layout. Preserve existing internal record type defaults and their support processes; the portal Flow explicitly supplies `Portal_Request` on the initial insert.

### Restrict existing Case creation automation to internal intake

During implementation, retrieve and identify the org's existing Case creation automation and the record type(s) used by internal intake. Its exact API name and entry criteria have not been established from the local files. Update its entry criteria or first decision so it executes only for those explicitly identified internal Case record types, retaining its other existing conditions. Exclude `Portal_Request` before any internal initialization, Box provisioning, or asynchronous work is scheduled.

Use the record type to distinguish the intake paths. Do not classify a Case as internally created using the submitter's profile, user type, Contact presence, or owner: an internal employee can submit through the portal. A blanket `RecordType != Portal_Request` condition is insufficient if other non-internal record types exist; use the confirmed internal record type allowlist. Resolve record type IDs per environment rather than embedding org-specific IDs.

The portal Screen Flow owns folder creation and Editor assignment for Portal Request Cases. Apply the same internal-only guard to any downstream or asynchronous branch of the existing creation automation that could otherwise provision them. Review update-triggered paths so later changes to a Portal Request do not re-enter internal initialization. Keep the record type stable through assignment and other Case automation.

Deploy the Support Process, record type, access configuration, and internal automation guard before activating and publishing the portal entry point. The existing internal Case creation path must continue to work with its existing record type and support process.

## Portal entry and access

Add an authenticated **Submit a Case** page in Experience Builder for `Default`, embed the active Flow using the standard Flow component, and add an entry to the site's navigation. Apply the same visibility to all authenticated members; internal members must see the same entry. Require login and do not grant the guest profile Flow access.

Use the site's configured membership profiles as the rollout inventory, including internal profiles. Salesforce site membership can be granted through profiles or permission sets; it is distinct from permissions to use the application. See [Add Members to Your Experience Cloud Site](https://help.salesforce.com/s/articleView?id=000397173&language=en_US&type=1).

Run the Screen Flow in **user context**. For every eligible profile, provision Flow execution/access, Case Create and Read, field access for the fields below, and access to the Portal Request record type. Use profile grants or automatically assigned, license-compatible permission sets so current and future members receive access without a separate opt-in. Add the appropriate Box package permissions and identity setup for each user population.

Inventory the licenses attached to all eligible profiles before implementation. Portal login alone does not establish Case or Box entitlement. Any eligible profile that cannot receive the required access is a rollout gap to resolve; do not silently exclude its users or switch to system context to bypass licensing. Acceptance requires coverage of every eligible profile.

## Screen 1 — Case details

Show the title **Submit a Case** and these inputs:

| Input | Required | Mapping / behavior |
| --- | --- | --- |
| Subject | Yes | `Case.Subject`; reject whitespace-only input and respect the field length. |
| Description | Yes | `Case.Description`; reject whitespace-only input and respect the field length. |

Use a **Submit Case** button. Explain that the Case is saved when submitted and that files are added on the following screen. Do not expose Record Type, Owner, Contact, collaborator, or destination folder as user inputs. Validate before creating anything.

Read the submitter from `$User.Id`. A missing `$User.ContactId` is valid and must not prevent submission. Resolve the active Case record type by `SobjectType = 'Case'` and `DeveloperName = 'Portal_Request'`. Fail before Case creation if it is missing, inactive, or unavailable to the user. Never hard-code a record type ID or fall back to another record type.

## Case creation and defaults

Create exactly one Case per submission and retain its ID in a private Flow variable. Retrieve its generated Case number for the upload screen and any post-create error message.

| Case field | Value |
| --- | --- |
| `Subject` | Validated Subject input. |
| `Description` | Validated Description input. |
| `RecordTypeId` | Resolved **Portal Request** record type ID. |
| `Status` | `New`, the default in **Portal Request Support**; confirm the org's actual API value. |
| `Origin` | `Web`, enabled for this record type; confirm the org's actual API value. |
| `Priority` | `Medium`, enabled for this record type; confirm the org's actual API value. |
| `ContactId` | `$User.ContactId` when populated; otherwise leave blank. |
| `AccountId` | The associated Contact's Account when available and readable; otherwise leave blank. |
| `OwnerId` | Internal submitter for internal Salesforce users who can own Cases; configured Case intake queue for external users. |

Resolve the queue by its configured developer name and verify that it supports Cases. Do not assign an external submitter as Case owner. Salesforce supplies `CreatedById`, which identifies the submitter for both populations. Existing validation rules must allow internal submissions with no Contact or Account.

Ensure the external submitter can read the new queue-owned Case through a license-supported sharing mechanism, such as a Contact-based sharing set where supported. Avoid account-wide sharing solely for this flow. Internal submitters retain access through ownership; review any automation that changes the owner. Salesforce Case access and Box folder access must both work independently.

## Box actions

Use the installed managed actions synchronously and in this order. Box documents both record folder creation and record collaboration as [Flow Actions](https://developer.box.com/guides/tooling/salesforce-toolkit/flow-actions). Resolve the exact action API names and exposed input/output bindings from the installed package during implementation; toolkit method names are not necessarily Flow action API names.

### 1. Create the Case folder

Select **Create Folder For Record ID**. Pass the newly created Case ID and use `Case-<CaseNumber>` as the folder name. Use the configured Case root; preconfigure it before rollout. Capture the returned folder ID as Flow Text and require a nonblank result. If the action exposes automatic current-user collaboration, disable it so the next action explicitly assigns the requested role.

Let the package maintain the Case/folder association in `box__FRUP__c`; do not manually insert association records. No duplicate folder-ID field on Case or folder template is required. See the [Box toolkit folder and collaboration contracts](https://developer.box.com/guides/tooling/salesforce-toolkit/methods).

### 2. Add the submitter as Editor

Reuse the action contract shown in [Box_Assign_Case_Collaborator.flow-meta.xml](../force-app/main/default/flows/Box_Assign_Case_Collaborator.flow-meta.xml):

| Action / input | Value |
| --- | --- |
| Action | `box__CreateCollaborationOnRecord_v2` |
| `recordId` | Newly created Case ID. |
| `userId` | `$User.Id` — the Salesforce user ID. |
| `collabType` | Literal `EDITOR`. |

If exposed, set `optCreateFolder = false`. Check the installed action's success/error outputs as well as its fault connector. A normal return with a failure or empty required output must not advance to upload. An already-existing collaboration is acceptable only after confirming it grants the required Editor access.

The existing flow's user-selection screen is not reused: the collaborator is always the authenticated submitter. Do not accept a collaborator ID, Case ID, or folder ID from a URL or Flow input variable.

### Transactions and identity

Set both Box actions to **Always start a new transaction**. The first boundary commits the Case before folder creation; the second commits the managed association before collaboration. This avoids callouts after uncommitted Salesforce writes. No extra user-facing screen is needed between these actions. Verify the settings in the deployed Flow and test through the published site. See [Salesforce Flow transactions](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_transaction.htm&language=en_US&type=5).

Configure Box's Experience Cloud integration and **Box App User (Experience Cloud)** permissions for external users. Verify the internal user's supported Box identity mapping separately. In both cases, the identity granted Editor access must be the identity used by the uploader. Complete service-account access, app authorization, CORS, and Experience Builder trust settings for the actual `Default` site domain, following [Box's Experience Cloud setup](https://support.box.com/hc/en-us/articles/26032384109075-Setting-up-Box-UI-Elements-in-Experience-Cloud). Keep credentials in the managed integration configuration.

## Screen 2 — Upload files

Render this screen only after the folder and Editor collaboration succeed. Show **Case <CaseNumber> created** and embed the managed **Box Content Uploader**, the Box File Upload UI Element requested for this flow.

Set its `folderId` to the folder ID returned by folder creation. Set `fileLimit` to a configurable value greater than one; use **10 files** as the initial design default. These properties are documented in [Box UI Elements in Salesforce](https://developer.box.com/guides/tooling/salesforce-toolkit/ui-elements). Confirm the installed component's exact Flow Builder name and runtime compatibility.

Files upload directly to that Box folder. Use the Box component rather than the Salesforce File Upload component; do not stage files in Salesforce Files. Let the component report per-file progress, success, and failures. Explain that the user should wait for uploads to finish before clicking **Finish**.

Assumption for this simple flow: attachments are optional for Case submission, and the uploader permits one or more files when supplied. The Case already exists even if the user uploads nothing or leaves this screen. Do not claim upload completion from Flow navigation alone or assume the managed component exposes an upload-complete output. A mandatory attachment gate would need verified component support and is not part of this design.

Disable Previous and Pause after submission. On Finish, return to the portal home or a configured completion destination without automatically starting another interview. Show a Case detail link only if the site has a working, authorized Case page.

## Failure and recovery behavior

Connect faults on lookups, Case creation, and Box actions to a concise message with a fixed error code. Do not display raw package errors or `$Flow.FaultMessage` to portal users.

| Failure point | User experience and recovery |
| --- | --- |
| Configuration or Case creation | Explain that submission did not complete; permit correction/retry only when no Case was created. |
| Folder creation | Show the saved Case number and `PORTAL_FOLDER_SETUP_FAILED`; tell the user the Case exists and file upload is unavailable. |
| Collaboration | Show the saved Case number and `PORTAL_FOLDER_ACCESS_FAILED`; keep the uploader hidden. |
| Individual upload | Retain the Case, folder, collaboration, and completed uploads; allow retry of failed files in the uploader. |

Box work and committed Salesforce transactions cannot be rolled back together. A timeout may mean the Box operation succeeded without a usable response. After a post-create failure, end the interview without a button that recreates the Case. An administrator reconciles the existing Case association, folder, and collaboration before repeating the failed step. Do not automatically delete the Case/folder or blindly create replacements. Dedicated resume tooling and cross-session duplicate-submission prevention are deferred.

## Related implementation changes

| Area | Required change |
| --- | --- |
| Support Process | Create active **Portal Request Support** with New (default), Working, and Closed; verify open/closed status flags. |
| Case record type | Define active **Portal Request** (`Portal_Request`), associate it with **Portal Request Support**, and configure allowed picklist defaults. Assign access/layouts to eligible profiles and support staff while preserving internal defaults. |
| Flow | Add `Portal_Create_Case` with two screens, Case creation, two managed Box actions, result checks, and fault screens. |
| Experience Cloud | Add and publish the authenticated page/navigation entry in **Default**; configure completion behavior. |
| Access | Cover every member profile with Case, field, record-type, Flow, and package permissions; include future-user provisioning. |
| Ownership and sharing | Configure the external intake queue and submitter access; verify internal ownership and existing reassignment behavior. |
| Box configuration | Verify Case root, service identity, external App User/internal identity mapping, package access, and site trust settings. |
| Existing Case creation automation | Identify the deployed automation and restrict it to the confirmed internal-intake record types. Exclude Portal Request before side effects or asynchronous scheduling, including when an internal Salesforce user submits through the portal. Preserve existing internal behavior. |
| Other Case automation | Review owner assignment, record type changes, folder creation, and collaboration automation for overlap. Preserve the Portal Request record type and ensure no competing rule provisions its folder or removes/downgrades its submitter. |

No new custom Apex, custom uploader, or custom Case fields are planned. Existing Case Team Assignment flows remain separate. Record the selected package action/component bindings and environment-specific queue/root configuration with the implementation.

## Acceptance checks

1. From the published `Default` site, test a representative user for **every eligible profile**, including a non-admin internal Salesforce user with no Contact and an external user. All can find and run the flow.
2. A valid submission creates one Case with the Portal Request record type and the expected fields, owner, and submitter identity. Internal users with blank Contact/Account succeed.
3. The managed folder action creates one Case-associated Box folder. The collaboration action grants the submitting user's actual Box identity `EDITOR` before upload is shown.
4. Upload one file, then multiple files. Confirm they appear in the associated folder, with no Salesforce file staging.
5. Verify the submitter can read the Case and use its folder. An unrelated portal user cannot access that Case or folder solely because of this feature; guest and nonmember access is denied.
6. Exercise missing configuration, insufficient package permissions, folder/collaboration failures, and partial upload failure. Messages accurately distinguish an unsaved request from an already-saved Case.
7. Finish without attachments, leave the upload screen, and retry a failed upload. Saved Cases and successful uploads remain intact; post-submit navigation does not repeat Case creation.
8. Verify transaction boundaries, identity mapping, upload rendering, and completion navigation in the published site for both internal and external users. Record actual results before declaring the implementation complete.
9. Confirm the Portal Request record type uses **Portal Request Support**, offers only New, Working, and Closed, and creates Cases as New. Support staff can move a Case to Working and then Closed; closing sets the Case's closed state. Box setup/upload leaves Status unchanged.
10. Submit through `Default` as both an external user and an internal Salesforce user. In both cases, verify the existing internal Case creation automation performs no internal initialization or Box work, including asynchronous work, and the portal Flow creates only one folder and Editor collaboration.
11. Create a Case through the existing internal intake path using its existing internal record type. Verify the existing creation automation still runs and its support process/defaults are unchanged. Updating a Portal Request must not cause it to enter that internal initialization path.
