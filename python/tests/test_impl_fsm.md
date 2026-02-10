# test_impl_fsm.py

Unit tests for the explicit FSM scaffold introduced in the `impl` workflow.

## Purpose

This test module validates deterministic behavior for the new workflow
orchestration contracts before production kernels are fully migrated.

## Coverage

- `WorkflowContext` helpers for attempts and payload/artifact merge behavior
- Transition table resolution and fail-fast validation behavior
- Orchestrator terminal behavior (`finish` / `fatal`) and log emission format
- Kernel registry scaffold integrity and placeholder safety behavior

## Design Rationale

The tests focus on objective control-flow semantics rather than model output
quality, ensuring that state routing behavior remains stable while stage
implementations evolve across future iterations.

