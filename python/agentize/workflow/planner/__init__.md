# Planner Package Interface

Public exports for the planner pipeline package.

## External Interface

### `run_planner_pipeline(...) -> dict[str, StageResult]`

Re-exported from `agentize.workflow.planner.__main__`. Executes the 5-stage planner
pipeline and returns stage results.

See `__main__.md` for the full signature and behavior details.

### `StageResult`

Dataclass re-exported from `agentize.workflow.planner.__main__` describing a single
stage execution (stage name, input/output paths, completed process).

### `PlannerTTY`

TTY output helper re-exported from `agentize.workflow.utils` for convenience.

## Internal Helpers

### `__getattr__(name: str)`

Lazy-loads `run_planner_pipeline` and `StageResult` from `__main__` to avoid eager
execution when importing the package.

### `__dir__() -> list[str]`

Returns a sorted list of public exports for tooling and `dir()` support.
