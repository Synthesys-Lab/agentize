# planRunner.ts

Command runner for Plan sessions that spawns the CLI process and emits run events.

## External Interface

### PlanRunner
- `run(input: RunPlanInput, onEvent: (event: RunEvent) => void)`: starts a CLI run and
  streams events to the callback.
- Spawn failures emit stderr lines with user-friendly guidance (including missing command hints).
- `stop(sessionId: string)`: terminates a running session.
- `isRunning(sessionId: string)`: reports whether a session is currently running.
- CLI execution is routed through `vscode/bin/lol-wrapper.js` so the shell-based
  `lol` function can be invoked from a subprocess.

## Internal Helpers

### buildCommand(prompt: string)
Returns the executable and arguments used to invoke the planning CLI, using `node`
to run the wrapper script while preserving the user-facing display string.

### attachLineReaders()
Converts stdout/stderr streams into line-based run events.
