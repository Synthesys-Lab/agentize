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
- `issueNumber`: GitHub issue number captured from plan output (optional).
- `issueState`: last known GitHub issue state (`open`, `closed`, `unknown`) used to gate implementation runs (optional).
  - `unknown` means the state could not be verified (missing `gh`, auth, or network).
- `implStatus`: implementation run status (`idle`, `running`, `success`, `error`).
- `refineRuns`: refinement run history for this session.
- `version`: schema version for persistence (optional, defaults to 1 for legacy sessions).
- `widgets`: widget timeline for the session (optional).
- `phase`: UI phase string (`idle`, `planning`, `plan-completed`, `refining`, `implementing`, `completed`) (optional).
- `activeTerminalHandle`: widget id of the active terminal handle used for log routing (optional).
- `createdAt`, `updatedAt`: timestamps.

### WidgetState
- `id`: stable widget identifier.
- `type`: widget type discriminator.
- `title`: optional widget title (terminal widgets).
- `content`: optional widget content payload (text/terminal lines).
- `metadata`: widget-specific configuration payload.
- `createdAt`: timestamp for ordering.

### WidgetType
Union of `text`, `terminal`, `progress`, `buttons`, `input`, and `status`.

### SessionStatus
Union of `idle`, `running`, `success`, and `error`.

## Internal Helpers

No internal helpers; this module only exports shared types.
