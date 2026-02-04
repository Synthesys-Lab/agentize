# Module: agentize.workflow.api

Public workflow API surface providing the Session DSL and ACW helpers.

## External Interfaces

### `Session`

```python
class Session:
    def __init__(...): ...
    def run_prompt(...): ...
    def stage(...): ...
    def run_parallel(...): ...
```

Re-export of `agentize.workflow.api.session.Session`.

### `StageResult`

```python
@dataclass
class StageResult:
    stage: str
    input_path: Path
    output_path: Path
    process: subprocess.CompletedProcess
```

Re-export of `agentize.workflow.api.session.StageResult`.

### `StageCall`

```python
@dataclass
class StageCall:
    stage: str
    prompt: str | Callable[[Path], str]
    backend: tuple[str, str]
    options: dict[str, Any]
```

Re-export of `agentize.workflow.api.session.StageCall`.

### `PipelineError`

```python
class PipelineError(RuntimeError): ...
```

Re-export of `agentize.workflow.api.session.PipelineError`.

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
    timeout: int = 3600,
    cwd: str | Path | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess
```

Re-export of `agentize.workflow.api.acw.run_acw`.

### `list_acw_providers`

```python
def list_acw_providers() -> list[str]
```

Re-export of `agentize.workflow.api.acw.list_acw_providers`.

### `ACW`

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
        runner: Callable[..., subprocess.CompletedProcess] | None = None,
    ) -> None: ...
    def run(self, input_file: str | Path, output_file: str | Path) -> subprocess.CompletedProcess: ...
```

Re-export of `agentize.workflow.api.acw.ACW`.

## Internal Helpers

This module only re-exports selected helpers and does not define its own internal
implementation.

## Design Rationale

- **Single entry point**: A stable import surface for the Session DSL and ACW helpers.
- **Focused exports**: Re-exports stay limited to workflow primitives without exposing
  internal convenience logic from other packages.
