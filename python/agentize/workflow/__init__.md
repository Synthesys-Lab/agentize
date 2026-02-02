# Module: agentize.workflow

Public interfaces for Python planner workflow orchestration.

## Exports

### From `utils.py`

#### `run_acw`

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

Wrapper around the `acw` shell function that builds and executes an ACW command with quoted paths.

**Parameters:**
- `provider`: Backend provider (`"claude"` or `"codex"`)
- `model`: Model identifier (e.g., `"sonnet"`, `"opus"`)
- `input_file`: Path to input prompt file
- `output_file`: Path for stage output
- `tools`: Tool configuration (Claude provider only)
- `permission_mode`: Permission mode override (Claude provider only)
- `extra_flags`: Additional CLI flags
- `timeout`: Execution timeout in seconds (default: 900)

**Returns:** `subprocess.CompletedProcess` with stdout/stderr captured

**Raises:** `subprocess.TimeoutExpired` if execution exceeds timeout

#### `PlannerTTY`

```python
class PlannerTTY:
    def __init__(self, *, verbose: bool = False) -> None: ...
    def term_label(self, label: str, text: str, style: str = "") -> None: ...
    def anim_start(self, label: str) -> None: ...
    def anim_stop(self) -> None: ...
    def timer_start(self) -> float: ...
    def timer_log(self, stage: str, start_epoch: float, backend: str | None = None) -> None: ...
```

TTY output helper with dot animations, timing logs, and styled labels. Respects `NO_COLOR`, `PLANNER_NO_COLOR`, and `PLANNER_NO_ANIM` environment variables.

### From `planner/`

#### `run_planner_pipeline`

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
    progress: PlannerTTY | None = None,
) -> dict[str, StageResult]
```

Execute the 5-stage planner pipeline: understander → bold → critique → reducer → consensus.

**Parameters:**
- `feature_desc`: Feature request description to plan
- `output_dir`: Directory for artifacts (default: `.tmp`)
- `backends`: Provider/model mapping per stage (default: understander uses claude/sonnet, others claude/opus)
- `parallel`: Run critique and reducer in parallel (default: True)
- `runner`: Callable for stage execution (default: `run_acw`, injectable for testing)
- `prefix`: Artifact filename prefix (default: timestamp-based)
- `output_suffix`: Suffix appended to stage output filenames (default: `-output.md`)
- `skip_consensus`: Skip the consensus stage when external synthesis is used (default: False)
- `progress`: Optional `PlannerTTY` for stage logs/animation

**Returns:** Dict mapping stage names to `StageResult` objects

**Raises:**
- `FileNotFoundError`: If required prompt templates are missing
- `RuntimeError`: If a stage execution fails

#### `StageResult`

```python
@dataclass
class StageResult:
    stage: str
    input_path: Path
    output_path: Path
    process: subprocess.CompletedProcess
```

Structured result for a single pipeline stage.

**Attributes:**
- `stage`: Stage name (e.g., `"understander"`, `"bold"`)
- `input_path`: Path to rendered input prompt file
- `output_path`: Path to stage output file
- `process`: Completed process with return code, stdout, stderr

## Module Organization

| Module | Purpose |
|--------|---------|
| `utils.py` | Reusable TTY and shell invocation utilities |
| `planner/` | Standalone planning pipeline package (`python -m agentize.workflow.planner`) |

## Error Handling

- Missing prompt templates raise `FileNotFoundError` with the missing path
- Stage execution failures raise `RuntimeError` with stage name and exit code
- Timeout during execution raises `subprocess.TimeoutExpired`

## Example

```python
from agentize.workflow import run_planner_pipeline, StageResult, PlannerTTY

# Run pipeline with custom backends
results = run_planner_pipeline(
    "Implement dark mode toggle",
    backends={"consensus": ("claude", "opus")},
    parallel=False,  # Deterministic order for debugging
)

# Check all stages completed successfully
for stage, result in results.items():
    assert result.process.returncode == 0
    print(f"{stage}: {result.output_path.read_text()[:100]}...")
```
