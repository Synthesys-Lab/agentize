# orchestrator.py

Finite-state orchestrator runtime for the `impl` workflow.

## Purpose

`orchestrator.py` provides a flat, deterministic loop that executes stage
handlers, merges stage outputs, resolves next stages through the transition
table, and exits only at terminal states.

## Core API

- `run_fsm_orchestrator(context, kernels, logger=print, max_steps=200)`
- `OrchestratorError` (reserved for explicit orchestration runtime failures)
- `StageHandler` / `KernelRegistry` type aliases

## Runtime Behavior

On each loop iteration:

1. Select stage handler from registry.
2. Execute handler and receive `StageResult`.
3. Merge payload/artifacts into `WorkflowContext`.
4. Resolve next stage from transition table.
5. Emit unified log line: `stage=<stage> event=<event> iter=<n> reason=<reason>`.

## Failure Handling

- Missing stage handler causes deterministic transition to `fatal`.
- Invalid transition/event resolution causes deterministic transition to
  `fatal` with diagnostic `fatal_reason`.
- `max_steps` guard prevents accidental infinite loops.

