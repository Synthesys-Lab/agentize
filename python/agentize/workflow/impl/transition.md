# transition.py

Transition table and validation for the explicit `impl` workflow FSM.

## Purpose

`transition.py` is the single source of truth for stage flow decisions. It
removes scattered branch logic and makes routing deterministic.

## Core API

- `TRANSITIONS`: mapping of `(stage, event) -> next_stage`
- `next_stage(stage, event)`: resolve one transition
- `validate_transition_table(table=None)`: fail-fast validation for wiring
- `TransitionError`: transition configuration/runtime error type

## Design Rationale

- Routing is represented as immutable data (`TRANSITIONS`) so behavior is easy
  to audit and test.
- `next_stage` validates both stage and event before lookup to avoid silent
  fallthrough.
- `validate_transition_table` checks required decision edges to prevent partial
  state-machine configuration.

## Transition Coverage

The table includes the expected implementation flow:

- `impl -> impl/review/fatal`
- `review -> pr/impl/fatal`
- `pr -> finish/impl/rebase/fatal`
- `rebase -> impl/fatal`

Terminal stages (`finish`, `fatal`) currently only accept `fatal` as an explicit
fallback route.

