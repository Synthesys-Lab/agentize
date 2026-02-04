# Module: agentize.workflow.planner

Package exports for the planner pipeline package.

## External Interfaces

### `run_planner_pipeline`

```python
def run_planner_pipeline(
    feature_desc: str,
    *,
    output_dir: str | Path = ".tmp",
    backends: dict[str, tuple[str, str]] | None = None,
    parallel: bool = True,
    runner: Callable[..., subprocess.CompletedProcess] = run_acw,
    prefix: str | None = None,
    output_suffix: str = "-output.md",
    skip_consensus: bool = False,
) -> dict[str, StageResult]
```

Re-export of the planner pipeline execution entry point from `pipeline.py`.

### `StageResult`

```python
@dataclass
class StageResult:
    stage: str
    input_path: Path
    output_path: Path
    process: subprocess.CompletedProcess
```

Re-export of the per-stage result dataclass.

## Internal Helpers

This module re-exports interfaces from `planner.pipeline` and does not define internal
helpers.
