# Module: agentize.workflow.planner (Deprecated Shim)

Backward-compatible re-exports for planner pipeline interfaces.

## External Interfaces

### `run_planner_pipeline`

```python
def run_planner_pipeline(
    feature_desc: str,
    *,
    output_dir: str | Path = ".tmp",
    backends: dict[str, tuple[str, str]] | None = None,
    runner: Callable[..., subprocess.CompletedProcess] = run_acw,
    prefix: str | None = None,
    output_suffix: str = "-output.md",
    skip_consensus: bool = False,
) -> dict[str, StageResult]
```

Re-export of the planner pipeline execution entry point.

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

### `run_acw`

```python
def run_acw(
    provider: str,
    model: str,
    input_file: str | Path,
    output_file: str | Path,
    *,
    tools: str | None = None,
    permission_mode: str | None = None,
    extra_flags: list[str] | None = None,
    timeout: int = 900,
) -> subprocess.CompletedProcess
```

Re-export of the ACW shell invocation helper from `agentize.workflow.api`.

## Internal Helpers

This module re-exports interfaces and does not define internal helpers.

## CLI Invocation

Use the runnable package for CLI execution:

```bash
python -m agentize.workflow.planner --feature-desc "Add dark mode" --issue-mode true
```
