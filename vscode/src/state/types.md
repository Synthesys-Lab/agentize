# types.ts

Shared state contracts for the Plan Activity Bar view and related tabs.

## External Interface

### AppState
- `activeTab`: which Plan view tab is active (`plan`, `repo`, `impl`, `settings`).
- `plan`: PlanState payload.
- `repo`, `impl`, `settings`: placeholders for future tabs.

### PlanState
- `sessions`: list of PlanSession entries.
- `draftInput`: current draft text for the New Plan input.

### PlanSession
- `id`: unique session identifier.
- `title`: short label derived from the prompt.
- `collapsed`: whether the UI is collapsed.
- `status`: session status.
- `prompt`: raw planning prompt.
- `command`: resolved CLI command string (optional).
- `logs`: log lines captured for this session.
- `createdAt`, `updatedAt`: timestamps.

### SessionStatus
Union of `idle`, `running`, `success`, and `error`.

## Internal Helpers

No internal helpers; this module only exports shared types.
