# Module: agentize.workflow

Public interfaces for Python planner and impl workflow orchestration.

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

Wrapper around the `acw` shell function that builds and executes an ACW command with
quoted paths.

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

#### `ACW`

```python
class ACW:
    def __init__(
        self,
        name: str,
        provider: str,
        model: str,
        timeout: int = 900,
        *,
        tools: str | None = None,
        permission_mode: str | None = None,
        extra_flags: list[str] | None = None,
        log_writer: Callable[[str], None] | None = None,
    ) -> None: ...
    def run(self, input_file: str | Path, output_file: str | Path) -> subprocess.CompletedProcess: ...
```

Class-based runner around `run_acw` that validates providers at construction and
emits start/finish timing logs.

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

TTY output helper with dot animations, timing logs, and styled labels. Respects
`NO_COLOR`, `PLANNER_NO_COLOR`, and `PLANNER_NO_ANIM` environment variables.

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

### From `impl/`

#### `run_impl_workflow`

```python
def run_impl_workflow(
    issue_no: int,
    *,
    backend: str = "codex:gpt-5.2-codex",
    max_iterations: int = 10,
    yolo: bool = False,
) -> None
```

Run the `lol impl` issue-to-implementation loop in Python. The workflow renders
prompts from `workflow/impl/continue-prompt.md`, runs `acw`, and manages git/PR
automation via shell commands.

**Parameters:**
- `issue_no`: Numeric issue identifier.
- `backend`: Backend in `provider:model` form.
- `max_iterations`: Maximum iterations before failing.
- `yolo`: Pass-through flag to `acw` for autonomous actions.

**Raises:**
- `ValueError`: Invalid arguments (issue number, backend format, max iterations).
- `ImplError`: Missing worktree, sync failure, prefetch failure, or max-iteration exhaustion.

#### `ImplError`

```python
class ImplError(RuntimeError):
    ...
```

Raised for workflow failures in `run_impl_workflow`.

## Module Organization

| Module | Purpose |
|--------|---------|
| `utils.py` | Reusable TTY and shell invocation utilities |
| `planner/` | Standalone planning pipeline package (`python -m agentize.workflow.planner`) |
| `planner.py` | Backward-compatible re-exports (deprecated) |
| `impl/` | Issue-to-implementation workflow (Python) with file-based prompt |

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
