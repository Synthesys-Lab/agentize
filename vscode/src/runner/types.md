# types.ts

Contracts for Plan command execution events.

## External Interface

### RunPlanInput
- `sessionId`: session identifier to associate with the run.
- `prompt`: prompt text passed to the CLI.
- `cwd`: working directory for the command.

### RunEvent
Union of events emitted during execution:
- `start`: command and cwd resolved.
- `stdout`: stdout line emitted.
- `stderr`: stderr line emitted.
- `exit`: process exit with code and signal.

## Internal Helpers

No internal helpers; this module only exports types.
