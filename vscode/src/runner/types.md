# types.ts

Contracts for Plan command execution events.

## External Interface

### RunPlanInput
- `sessionId`: session identifier to associate with the run.
- `command`: which command to execute (`plan`, `refine`, or `impl`).
- `prompt`: prompt text passed to the CLI (required for `plan` and `refine`).
- `issueNumber`: issue number passed to the CLI (required for `impl`).
- `cwd`: working directory for the command.
- `refineIssueNumber`: required issue number enabling `lol plan --refine <issue> "<prompt>"` when `command=refine` (optional field to keep `RunPlanInput` compact).
- `runId`: optional run identifier used to associate streamed output with a specific UI sub-pane (e.g., a specific refinement run within a session).
- `backend`: optional backend override in `provider:model` format (used for `lol plan` and `lol impl`).

### RunCommandType
Union of `plan`, `refine`, and `impl` command identifiers used by the runner and webview routing.

### RunEvent
Union of events emitted during execution:
- `start`: command and cwd resolved.
- `stdout`: stdout line emitted.
- `stderr`: stderr line emitted.
- `exit`: process exit with code and signal.
Each event includes `commandType` so consumers can route plan vs. implementation output.

## Internal Helpers

No internal helpers; this module only exports types.
