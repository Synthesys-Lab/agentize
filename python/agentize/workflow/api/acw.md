# acw.py

ACW invocation helpers for workflow orchestration with consistent timing logs and
provider validation.

## External Interfaces

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

Runs the `acw` shell function with file-based input/output. The helper resolves the
`acw.sh` script location, merges environment overrides, and invokes `bash -c` with
quoted arguments.

**Parameters**:
- `provider`: Backend provider (e.g., `"claude"`, `"codex"`).
- `model`: Model identifier.
- `input_file`: Path to the prompt file.
- `output_file`: Path for the response file.
- `tools`: Tool configuration (Claude provider only).
- `permission_mode`: Permission mode override (Claude provider only).
- `extra_flags`: Additional CLI flags for the provider.
- `timeout`: Execution timeout in seconds.
- `cwd`: Optional working directory for the subprocess.
- `env`: Optional environment overrides merged into `os.environ`.

**Returns**: `subprocess.CompletedProcess` with stdout/stderr captured.

**Raises**: `subprocess.TimeoutExpired` on timeout.

### `list_acw_providers`

```python
def list_acw_providers() -> list[str]
```

Returns the provider list from `acw --complete providers`. The result is cached in
memory and refreshed on first invocation.

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

Class-based runner that validates providers (unless a custom runner is supplied) and
emits start/finish timing logs in the format:
- `agent <name> (<provider>:<model>) is running...`
- `agent <name> (<provider>:<model>) runs <seconds>s`

### `run`

```python
def run(
    input_file: str | Path,
    output_file: str | Path,
    *,
    name: str,
    provider: str,
    model: str,
    tools: str | None = None,
    permission_mode: str | None = None,
    extra_flags: list[str] | None = None,
    timeout: int = 900,
    cwd: str | Path | None = None,
    env: dict[str, str] | None = None,
    log_writer: Callable[[str], None] | None = None,
) -> subprocess.CompletedProcess
```

Convenience helper that wraps `ACW` to execute a single stage with timing logs.

## Internal Helpers

### `_resolve_acw_script()`

Resolves the `acw.sh` path from `PLANNER_ACW_SCRIPT` or defaults to
`$AGENTIZE_HOME/src/cli/acw.sh`.

### `_resolve_overrides_cmd()`

Sources `AGENTIZE_SHELL_OVERRIDES` when present to load shell overrides for `acw`.

## Design Rationale

- **Unified ACW execution**: Centralizing the wrapper keeps command construction,
  environment setup, and logging consistent across workflow stages.
- **Composable runners**: The `ACW` class accepts a custom runner for tests while
  preserving production logging behavior.
