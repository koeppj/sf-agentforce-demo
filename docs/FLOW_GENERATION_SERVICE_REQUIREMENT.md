# Flow Generation Service Requirement

## Purpose

The requested **Add Case Team Assignment** and **Remove Case Team Assignment** screen flows cannot be created in this workspace until the Flow-generation MCP service is available.

## Required service

The installed `automation-flow-generate` skill requires an MCP tool named:

```
execute_metadata_action
```

The tool must support these actions, in this order:

1. `fetchGroundedObjectMetadata`
2. `flowElementSelection`
3. `flowElementGeneration`

The first action accepts a single-flow `userPrompt` and an `inflightMetadata` array. The second accepts the same prompt, the exact `groundingMetadata` string returned by the first action, and an `operationId`. The third accepts that `operationId` and `requestSource: "A4V"`; it must be called repeatedly until it returns `isComplete: true`, at which point it returns the Flow XML.

Because Add and Remove are separate flows, each requires its own complete three-step pipeline. The pipelines must run sequentially, not in parallel.

## Why this service is required

The installed skill explicitly prohibits hand-authoring or manually editing Flow XML. Its required pipeline grounds the flow against the connected org schema and generates the Flow metadata. This is intended to prevent invalid Flow XML, unsupported screen components, and incorrect record-operation wiring.

## Evidence from this workspace

The service was checked twice in the current environment:

- The callable-tool registry (`ALL_TOOLS`) contains no tool named `execute_metadata_action` and no Flow-generation equivalent.
- Invoking `tools.execute_metadata_action(...)` returned: `TypeError: tools.execute_metadata_action is not a function`.

This is not a Salesforce CLI or org-authentication problem. Salesforce CLI access is available and was used successfully to validate and deploy the Case Team Assignment layout and permission set to `agentforce-demo`.

## What must change

Enable or attach the MCP service/plugin that exposes `execute_metadata_action` to this Codex workspace. Its callable interface must provide all three actions above. The service's provider or connector name is not exposed by the current workspace tool registry, so the environment administrator must identify and enable the connector that supplies this Flow-generation capability.

## Verification after enablement

Before retrying flow generation, confirm that the callable-tool registry includes `execute_metadata_action`. Then generate the flows with two separate pipelines:

1. `Add_Case_Team_Assignment` — accepts `recordId`, selects an active User and a role, detects duplicates, creates the assignment, and sets `Case_User_Key__c`.
2. `Remove_Case_Team_Assignment` — accepts `recordId`, presents that Case's assignments, requires confirmation, and deletes the selected assignment.

After both flows are generated, add their flow-access entries to `Case_Team_Assignment_Manager` and deploy the flows and permission set together.
