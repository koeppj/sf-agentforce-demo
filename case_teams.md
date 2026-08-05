# Case Team Assignment - Implementation Plan

## Objective

Create a child object named **Case Team Assignment** so a user can assign a Salesforce User to a Case with one role: **Editor** or **Viewer**. The record is managed from the Case record page through dedicated Add and Remove flows, and Flow uses the API values `EDITOR` and `VIEWER`.

## Recommended data model

| Item | Design |
| --- | --- |
| Object | `Case_Team_Assignment__c` - label **Case Team Assignment**, plural **Case Team Assignments** |
| Case relationship | Required Master-Detail field `Case__c` to `Case`; child relationship label **Case Team Assignments** and relationship name `CaseTeamAssignments` |
| Assigned user | Lookup field `Assigned_User__c` to `User`, filtered to active users; required at record validation |
| Role | Required, restricted Picklist field `Role__c` with API values `EDITOR` and `VIEWER`, labelled **Editor** and **Viewer** |
| Record name | Auto Number, for example `CTA-{00000}`, because the assignment does not need a user-entered name |
| Sharing | `ControlledByParent`, inherited from the Case Master-Detail relationship |

Use a Master-Detail relationship for Case, rather than a lookup, so an assignment cannot exist without a Case, Case access governs child access, and deleting a Case removes its assignments. `Assigned_User__c` remains a lookup because the assigned Salesforce User is a participant, not the owner of the child relationship.

Salesforce does not support a required lookup to `User` with `SetNull` delete behavior. The `Assigned_User_Required` validation rule therefore enforces the required-user rule.

### Integrity rule

Each Salesforce User may be assigned only once per Case. `Case_User_Key__c` is a hidden, unique, 37-character text field populated as `<CaseId>-<AssignedUserId>`. A duplicate insert then fails reliably even when two users create the assignment at the same time. The Add flow also surfaces a friendly duplicate message before insert whenever possible.

## Metadata to add

1. Create `force-app/main/default/objects/Case_Team_Assignment__c/Case_Team_Assignment__c.object-meta.xml` with a concise object description, Auto Number name field, `ControlledByParent` sharing, and deployed/public status.
2. Add the three functional fields under `objects/Case_Team_Assignment__c/fields/`:
   - `Case__c.field-meta.xml` - Master-Detail to Case, relationship order `0`.
   - `Assigned_User__c.field-meta.xml` - Lookup to User with `SetNull` delete behavior and an active-user filter.
   - `Role__c.field-meta.xml` - restricted Picklist containing `EDITOR` and `VIEWER`.
3. Add `Case_User_Key__c.field-meta.xml` as a unique internal text field. Include field descriptions and inline help text for every field.
4. Add `Assigned_User_Required.validationRule-meta.xml` so no assignment can be saved without an assigned User.
5. Create the dedicated `Case_Team_Assignment_Manager` permission set. It grants Case and Case Team Assignment read access, access to `Assigned_User__c`, and the ability to search active Salesforce Users. Add flow access for the Add and Remove flows after they are created.

The flows, rather than direct object permissions, perform assignment creation and deletion. Salesforce requires object Edit permission when direct Delete permission is granted, which conflicts with the rule that existing assignments must not be edited.

## Case-page experience

Use a **Related List** (or Dynamic Related List - Single), not an object list view, on the Case Lightning record page. A normal List View is scoped to the Case Team Assignment object and does not automatically filter itself to the Case being viewed.

Configure the Case related list as follows:

- Related list label: **Case Team Assignments**.
- Columns: Assigned User, Role, Created By, Created Date.
- Do not expose the standard **New**, **Edit**, or **Delete** actions.
- Provide two flow-launch actions from the **Case Team Assignments** related list:
  - **Add Case Team Member** launches the Add flow and passes the current Case ID.
  - **Remove Case Team Member** launches the Remove flow for the selected assignment and passes the assignment ID.

These flow-launch actions are the only supported team-management entry points. The Case ID is inferred from the Case record-page context; it is not entered by the user.

Also create an optional standalone list view at `objects/Case_Team_Assignment__c/listViews/All_Case_Team_Assignments.listView-meta.xml` for administrators. It should show Case, Assigned User, Role, Created Date, and Created By, use the `Everything` scope, and be visible to all authorized users. This supports cross-Case administration but is not the Case-page related list.

## Automation

### Add Case Team Member flow

Build a Case-launched screen flow, **Add Case Team Member**, with `recordId` as an input variable.

1. Confirm that `recordId` identifies a Case and that the running user has edit access to that Case; only then allow the change.
2. Display an active User lookup and a Role picklist whose stored values are exactly `EDITOR` and `VIEWER`.
3. Check for an existing Case/User assignment. If found, show an actionable message that the User is already on the Case Team; do not create a duplicate or change the assigned role.
4. Create the child record and populate `Case__c`, `Assigned_User__c`, `Role__c`, and `Case_User_Key__c` (`<CaseId>-<AssignedUserId>`).
5. Refresh the Case record page after successful creation.

### Remove Case Team Member flow

Build a screen flow, **Remove Case Team Member**, with an input variable for the selected Case Team Assignment record ID.

1. Query the selected assignment and its parent Case.
2. Confirm that the running user has edit access to the parent Case; only then allow removal.
3. Display the assigned User and Role, and require explicit confirmation.
4. Delete the selected `Case_Team_Assignment__c` record only after confirmation.
5. Refresh the Case record page after successful deletion.

An assignment's role is not editable. To use a different role, remove the User from the Case Team and add them again with the required role.

### Scope boundary

This work does not modify or invoke `Box_Assign_Case_Collaborator.flow-meta.xml`. The existing Box collaboration flow remains independent and will be handled in a separate step. The Add and Remove flows create and delete only `Case_Team_Assignment__c` records.

## Validation and acceptance criteria

1. A user who can edit a Case and has the dedicated permission set can add an active Salesforce User to that Case as Editor or Viewer from the Case Team Assignments related list.
2. The Add flow stores only `EDITOR` or `VIEWER` in `Role__c`.
3. The Case page related list immediately shows the assignment, assigned User, and role.
4. The same Case/User pair cannot be created twice. To assign a different role, the existing assignment must be removed and recreated.
5. A user who can edit a Case and has the dedicated permission set can remove an assignment from the Remove flow.
6. A user without edit access to a Case cannot change its team membership, and no user can edit an existing assignment through the delivered permissions or actions.
7. Deleting a Case cascades to its Case Team Assignments.
8. Validate source with `sf project deploy validate` and verify the related-list flow actions, role values, duplicate handling, permissions, and both flow paths in a sandbox before deployment.

## Delivery order and status

1. **Completed:** Build and deploy the custom object and fields, including the active-User lookup filter, restricted Role values, and unique Case/User key.
2. **Completed:** Add and deploy the `Assigned_User_Required` validation rule.
3. **Completed:** Create and deploy `Case_Team_Assignment_Manager` to `agentforce-demo`. Assign it to authorized Case editors after the flow-access entries are added.
4. **Completed:** Retrieve and deploy the Case Team Assignment object layout. Salesforce automatically includes the required `Case__c` Master-Detail field in the standard New dialog, so that dialog is not used for team management.
5. **Pending:** Add the Case Team Assignments related list and the two flow-launch actions to the Case Lightning record page. The record-page changes are owned by the page configurator.
6. **Paused, needs manual cleanup:** The `execute_metadata_action` Flow-generation service is now available; see `FLOW_GENERATION_SERVICE_REQUIREMENT.md` for history. The **Add Case Team Member** flow (`Add_Case_Team_Member.flow-meta.xml`) was built, fixed, validated, and deployed to `agentforce-demo`, but was then targeted for removal. Deletion via `sf project delete source`, via an Obsolete-status redeploy, and via an explicit `destructiveChanges.xml` deploy all failed identically with `insufficient access rights on cross-reference id` (likely a permission gap for the deploying user against the flow's `UserRecordAccess` query). Current state: the flow is deployed to `agentforce-demo` with `Status=Obsolete` (deactivated, cannot run), and the local file still exists at the path above with `<status>Obsolete</status>`. **Manual action needed:** delete the flow from the org via Setup → Flows (or grant broader access and retry `sf project delete source --metadata Flow:Add_Case_Team_Member`), and delete/restore the local file as desired. Known gaps noted during the build (relevant only if this flow is revived instead of deleted): the Role screen field only offered the Editor choice, not Viewer, and the flow's display label read "Start Screen Flow" instead of "Add Case Team Member". **Pending:** Build and test the Remove Case Team Member flow.
7. **Pending:** Add flow-access entries to `Case_Team_Assignment_Manager` for both flows, deploy the updated permission set, then run the acceptance tests above.

## Access decision

Anyone who can edit a Case and is assigned `Case_Team_Assignment_Manager` can manage its Case Team through the two flow actions. No separate Case Team manager group is required.
