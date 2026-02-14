# types.ts

Contracts for Plan command execution events.

## External Interface

### RunPlanInput
- `sessionId`: session identifier to associate with the run.
- `command`: which CLI subcommand to execute (`plan` or `impl`).
- `prompt`: prompt text passed to the CLI (required for `plan`).
- `issueNumber`: issue number passed to the CLI (required for `impl`).
- `cwd`: working directory for the command.

### RunCommandType
Union of `plan` and `impl` command identifiers used by the runner and webview routing.

### RunEvent
Union of events emitted during execution:
- `start`: command and cwd resolved.
- `stdout`: stdout line emitted.
- `stderr`: stderr line emitted.
- `exit`: process exit with code and signal.
Each event includes `commandType` so consumers can route plan vs. implementation output.

## Internal Helpers

No internal helpers; this module only exports types.
