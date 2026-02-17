# planRunner.ts

Command runner for Plan sessions that spawns the CLI process and emits run events.
It supports both `plan` and `impl` CLI subcommands.

## External Interface

### PlanRunner
- `run(input: RunPlanInput, onEvent: (event: RunEvent) => void)`: starts a CLI run and
  streams events to the callback.
- Spawn failures emit stderr lines with user-friendly guidance (including missing command hints).
- `stop(sessionId: string)`: terminates a running session.
- `isRunning(sessionId: string, commandType?: RunCommandType)`: reports whether a session is currently running (optionally scoped to `plan` or `impl`).
- CLI execution is routed through `vscode/bin/lol-wrapper.js` so the shell-based
  `lol` function can be invoked from a subprocess.
- Each emitted event includes `commandType` so callers can route plan and implementation logs separately.
- On POSIX systems, runs are started in a dedicated process group so `stop()` can signal
  the whole group (`SIGTERM`, then `SIGKILL` fallback) instead of only the wrapper PID.
- Stopped processes remain tracked until their actual `exit` event arrives, which keeps
  running-state checks aligned with real process lifetime.

## Internal Helpers

### buildCommand(input: RunPlanInput)
Returns the executable and arguments used to invoke the CLI (`lol plan`, `lol plan --refine <issue> "<prompt>"`, or `lol impl <issue>`), using `node`
to run the wrapper script while preserving the user-facing display string.
When `input.backend` is provided, `buildCommand` appends `--backend <provider:model>`
to `lol plan` and `lol impl` runs (including refine mode).

### attachLineReaders()
Converts stdout/stderr streams into line-based run events.
