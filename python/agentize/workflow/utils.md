# Module: agentize.workflow.utils

Reusable shell invocation utilities for workflow orchestration.

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
    timeout: int = 900,
) -> subprocess.CompletedProcess
```

Wrapper around the `acw` shell function that builds and executes an ACW command with
quoted paths.

**Parameters:**
- `provider`: Backend provider (e.g., `"claude"`, `"codex"`)
- `model`: Model identifier (e.g., `"sonnet"`, `"opus"`)
- `input_file`: Path to input prompt file
- `output_file`: Path for stage output
- `tools`: Tool configuration (Claude provider only)
- `permission_mode`: Permission mode override (Claude provider only)
- `extra_flags`: Additional CLI flags
- `timeout`: Execution timeout in seconds (default: 900)

**Returns:** `subprocess.CompletedProcess` with stdout/stderr captured

**Raises:** `subprocess.TimeoutExpired` if execution exceeds timeout

**Environment:**
- `AGENTIZE_HOME`: Used to locate `acw.sh` script
- `PLANNER_ACW_SCRIPT`: Override path to `acw.sh` (for testing)

### `list_acw_providers`

```python
def list_acw_providers() -> list[str]
```

Fetch the list of supported providers by calling `acw --complete providers` using
`run_acw` script resolution rules.

**Behavior:**
- Returns the list of non-empty lines from the completion output.
- Raises `RuntimeError` if completion fails or returns no providers.
- Caches the result in memory to avoid repeated subprocess calls.

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
    ) -> None: ...
    def run(self, input_file: str | Path, output_file: str | Path) -> subprocess.CompletedProcess: ...
```

Class-based runner around `run_acw` that validates providers at construction and emits
start/finish timing logs.

**Constructor parameters:**
- `name`: Stage/agent label used in log lines.
- `provider`: Backend provider (validated via `list_acw_providers`).
- `model`: Model identifier.
- `timeout`: Execution timeout in seconds (default: 900).
- `tools`: Tool configuration (Claude provider only).
- `permission_mode`: Permission mode override (Claude provider only).
- `extra_flags`: Additional CLI flags.
- `log_writer`: Optional callable that receives log lines.

**Run behavior:**
- Emits `agent <name> (<provider>:<model>) is running...` before invoking `run_acw`.
- Emits `agent <name> (<provider>:<model>) runs <seconds>s` after completion.

## Internal Helpers

### `_resolve_acw_script()`

Resolves the `acw.sh` path from `PLANNER_ACW_SCRIPT` or defaults to
`$AGENTIZE_HOME/src/cli/acw.sh`.

### `_resolve_overrides_cmd()`

Resolves optional shell overrides by sourcing `AGENTIZE_SHELL_OVERRIDES` when present.

## Example

```python
from agentize.workflow.utils import ACW

runner = ACW(name="understander", provider="claude", model="sonnet")
result = runner.run("input.md", "output.md")
print(result.returncode)
```

## Design Rationale

- **Single invocation path**: `run_acw` centralizes shell execution so workflow stages
  behave consistently across CLI and library usage.
- **Provider validation**: `ACW` validates provider names once at construction and logs
  timing so pipeline stages surface progress uniformly.
