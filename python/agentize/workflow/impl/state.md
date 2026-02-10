# state.py

State contracts for the explicit `impl` workflow finite-state machine.

## Purpose

`state.py` defines stable, reusable contracts for stage handlers and the
orchestrator without tying orchestration logic to concrete kernel
implementations.

## Core Types

- `Stage`: stage literals (`impl`, `review`, `pr`, `rebase`, `finish`, `fatal`)
- `Event`: event literals emitted by stage handlers
- `StageResult`: structured output from a single stage execution
- `WorkflowContext`: mutable runtime context shared across stage executions

## Design Rationale

- Explicit string constants keep transition and logging logic deterministic.
- `StageResult` carries both control information (`event`, `reason`) and data
  payload (`payload`, `artifacts`, `metrics`) so stage handlers can stay focused
  on their own concerns.
- `WorkflowContext` centralizes mutable flow data and provides helper methods to
  update attempt counters and merge stage outputs consistently.

## Integration Contract

- Stage handlers return a `StageResult`.
- Orchestrator reads `StageResult.event` to compute next stage from transition
  table.
- Payload keys `review_feedback`, `parse_feedback`, and `ci_feedback` are
  recognized and mirrored onto dedicated context fields.

