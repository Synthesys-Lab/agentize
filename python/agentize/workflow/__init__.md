# Module: agentize.workflow

Public interfaces for Python planner workflow orchestration.

## Exports

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
- `progress`: Optional `PlannerTTY` (from `agentize.workflow.planner`) for stage logs/animation

**Returns:** Dict mapping stage names to `StageResult` objects

**Raises:**
- `FileNotFoundError`: If required prompt templates are missing
- `RuntimeError`: If a stage execution fails

### `StageResult`

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

## Error Handling

- Missing prompt templates raise `FileNotFoundError` with the missing path
- Stage execution failures raise `RuntimeError` with stage name and exit code
- Timeout during execution raises `subprocess.TimeoutExpired`

## Example

```python
from agentize.workflow import run_planner_pipeline, StageResult

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
