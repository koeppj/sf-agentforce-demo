# Case Team Assignment — Implementation Plan

## Objective

Create a child object named **Case Team Assignment** so a user can assign a Salesforce User to a Case with one role: **Editor** or **Viewer**. The record must be manageable from the Case record page and usable by Flow with the API values `EDITOR` and `VIEWER`.

## Recommended data model

| Item | Design |
| --- | --- |
| Object | `Case_Team_Assignment__c` — label **Case Team Assignment**, plural **Case Team Assignments** |
| Case relationship | Required Master-Detail field `Case__c` to `Case`; child relationship label **Case Team Assignments** and relationship name `CaseTeamAssignments` |
| Assigned user | Required Lookup field `Assigned_User__c` to `User`, with a lookup filter for active users |
| Role | Required, restricted Picklist field `Role__c` with API values `EDITOR` and `VIEWER`, labelled **Editor** and **Viewer** respectively |
| Record name | Auto Number, for example `CTA-{00000}`, because the assignment itself does not need a user-entered name |
| Sharing | `ControlledByParent`, inherited from the Case Master-Detail relationship |

Use a Master-Detail relationship for Case, rather than a lookup, so an assignment cannot exist without a Case, Case access governs child access, and deleting a Case removes its assignments. `Assigned_User__c` remains a lookup because the assigned Salesforce User is a participant, not the owner of the child relationship.

### Integrity rule

Each Salesforce User may be assigned only once per Case. Add a hidden text field `Case_User_Key__c` (unique, 37 characters), populated before save as `<CaseId>-<AssignedUserId>`. A duplicate insert will then fail reliably even when two users create the assignment at the same time. Surface a friendly error in the add flow before the database insert when possible.

## Metadata to add

1. Create `force-app/main/default/objects/Case_Team_Assignment__c/Case_Team_Assignment__c.object-meta.xml` with a concise object description, Auto Number name field, `ControlledByParent` sharing, and deployed/public status.
2. Add the three functional fields under `objects/Case_Team_Assignment__c/fields/`:
   - `Case__c.field-meta.xml` — Master-Detail to Case, relationship order `0`.
   - `Assigned_User__c.field-meta.xml` — required Lookup to User with `SetNull` delete behavior and an active-user filter.
   - `Role__c.field-meta.xml` — restricted Picklist containing `EDITOR` and `VIEWER`.
3. Add `Case_User_Key__c.field-meta.xml` as a unique internal text field. Include field descriptions and inline help text for every field.
4. Create `Case_Team_Assignment__c` object and field permissions in the Case-edit permission sets. Grant read/create/delete (not edit) on the child object to the same users who can edit Cases. Because sharing is `ControlledByParent`, these users can manage assignments only for Cases they can edit. Grant read access to the assigned-user and role fields where the related list is shown.

## Case-page experience

Use a **Related List** (or Dynamic Related List — Single), not an object list view, on the Case Lightning record page. A normal List View is scoped to the Case Team Assignment object and does not automatically filter itself to the Case being viewed.

Configure the Case related list as follows:

- Related list label: **Case Team Assignments**.
- Columns: Assigned User, Role, Created By, Created Date.
- Actions: **New** and **Delete** only; do not expose **Edit**, subject to the user's child-object permissions.
- Add a custom Case quick action labelled **Manage Case Team** that launches the management screen flow described below. This is the primary guided experience; the related-list actions remain useful for power users.

Also create an optional standalone list view at `objects/Case_Team_Assignment__c/listViews/All_Case_Team_Assignments.listView-meta.xml` for administrators. It should show Case, Assigned User, Role, Created Date, and Created By, use the `Everything` scope, and be visible to all authorized users. This supports cross-Case administration but is not the Case-page related list.

## Automation

### Add/remove management flow

Build a Case-launched screen flow, **Manage Case Team**, with `recordId` as an input variable.

1. Confirm that `recordId` is a Case and that the running user has edit access to that Case; only then allow Case Team changes.
2. Query and display existing `Case_Team_Assignment__c` records for the Case.
3. For an add operation, use an active User lookup and a Role picklist whose stored values are exactly `EDITOR` and `VIEWER`.
4. Check for an existing Case/User assignment. If found, show an actionable message that the user is already on the Case Team; do not create a duplicate or change the assigned role.
5. Create the child record and populate `Case_User_Key__c`.
6. For removal, require the user to select an existing assignment, confirm removal, then delete the child record.
7. Refresh the Case record page after successful create or delete.

An assignment's role is not editable. Do not grant the child object's Edit permission or expose an Edit action. To use a different role, remove the User from the Case Team and add them again with the required role.

### Scope boundary

This work does not modify or invoke `Box_Assign_Case_Collaborator.flow-meta.xml`. The existing Box collaboration flow remains independent and will be handled in a separate step. **Manage Case Team** creates and removes only `Case_Team_Assignment__c` records.

## Validation and acceptance criteria

1. A user who can edit a Case can add an active Salesforce User to that Case as Editor or Viewer from the Case page.
2. The add flow stores only `EDITOR` or `VIEWER` in `Role__c`.
3. The Case page related list immediately shows the assignment and its role.
4. The same Case/User pair cannot be created twice. To assign a different role, the existing assignment must be removed and recreated.
5. A user who can edit a Case can remove an assignment from its management flow or related list.
6. A user without edit access to a Case cannot change its team membership, and no user can edit an existing assignment through the delivered permissions or actions.
7. Deleting a Case cascades to its Case Team Assignments.
8. Validate source with `sf project deploy validate` and verify the related list, quick action, role values, duplicate handling, and permissions in a sandbox before deployment.

## Delivery order

1. Build and deploy the custom object and fields.
2. Add permission-set access and test with both an authorized and unauthorized user.
3. Add the related list and **Manage Case Team** action to the Case Lightning record page.
4. Build and test the management flow, including duplicate and remove paths.
5. Deploy to the target org and run the acceptance tests above.

## Access decision

Anyone who can edit a Case can manage its Case Team: they may add a User with a role or remove an existing assignment. No separate Case Team manager group is required.
