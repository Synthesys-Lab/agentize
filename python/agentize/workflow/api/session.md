# session.py

Session DSL for running staged agent workflows with consistent artifact handling, retries, and parallel execution.

## External Interface

### `Session`

```python
def __init__(
    self,
    output_dir: str | Path,
    prefix: str,
    *,
    runner: Callable[..., subprocess.CompletedProcess] = run_acw,
    input_suffix: str = "-input.md",
    output_suffix: str = "-output.md",
) -> None
```

**Purpose**: Configure a workflow session rooted at `output_dir` with a shared artifact prefix and an injectable ACW runner.

**Parameters**:
- `output_dir`: Directory for input/output artifacts (created if missing).
- `prefix`: Filename prefix used when input/output paths are not overridden.
- `runner`: ACW-compatible callable (defaults to `run_acw`).
- `input_suffix`: Default suffix for generated input filenames.
- `output_suffix`: Default suffix for generated output filenames.

### `Session.run_prompt()`

```python
def run_prompt(
    self,
    name: str,
    prompt: str | Callable[[Path], str],
    backend: tuple[str, str],
    *,
    tools: str | None = None,
    permission_mode: str | None = None,
    timeout: int = 3600,
    extra_flags: list[str] | None = None,
    retry: int = 0,
    retry_delay: float = 0,
    input_path: str | Path | None = None,
    output_path: str | Path | None = None,
) -> StageResult
```

Runs a single stage with retries and output validation.

**Behavior**:
- Resolves input/output paths from `prefix` + suffixes unless overrides are provided.
- Writes the prompt to the input path (string content or a writer callable).
- Executes the runner with stage-level tools and permission mode.
- Validates output (non-zero exit, missing output, or empty output triggers retry).
- Retries up to `1 + retry` attempts; raises `PipelineError` on failure.

### `Session.stage()`

```python
def stage(
    self,
    name: str,
    prompt: str | Callable[[Path], str],
    backend: tuple[str, str],
    **opts: Any,
) -> StageCall
```

Creates a lightweight stage call object for `run_parallel()`.

### `Session.run_parallel()`

```python
def run_parallel(
    self,
    calls: Iterable[StageCall],
    *,
    max_workers: int = 2,
    retry: int = 0,
    retry_delay: float = 0,
) -> dict[str, StageResult]
```

Runs multiple stages concurrently with a shared retry policy and returns results keyed by stage name.

### `StageResult`

```python
@dataclass
class StageResult:
    stage: str
    input_path: Path
    output_path: Path
    process: subprocess.CompletedProcess

    def text(self) -> str: ...
```

Represents a successful stage execution. `.text()` reads the output file as a string.

### `StageCall`

```python
@dataclass
class StageCall:
    stage: str
    prompt: str | Callable[[Path], str]
    backend: tuple[str, str]
    options: dict[str, Any]
```

Captures the inputs for a stage scheduled via `run_parallel()`.

### `PipelineError`

```python
class PipelineError(RuntimeError):
    stage: str
    attempts: int
    last_error: Exception | str
```

Raised after retry exhaustion, carrying stage metadata and the last failure detail.

## Internal Helpers

- `_resolve_paths()`: Applies default suffixes and normalizes path overrides.
- `_write_prompt()`: Writes prompt content to the input artifact path.
- `_run_with_retries()`: Encapsulates retry loop and validation checks.
- `_validate_output()`: Ensures successful exit code and non-empty output.

## Design Rationale

- **Consistent artifacts**: Centralized path resolution ensures predictable filenames and keeps workflows focused on orchestration logic.
- **Shared validation**: Output checks and retries live in one place to avoid duplicated error handling across pipelines.
- **Minimal concurrency**: A small `run_parallel()` wrapper covers the common fan-out use case without adding heavy orchestration layers.
