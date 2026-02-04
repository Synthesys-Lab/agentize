# Module: agentize.workflow.utils

Compatibility exports for workflow utilities plus a stable import surface for helper
modules under `agentize.workflow.utils.*`.

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

Re-export of `agentize.workflow.utils.acw.run_acw`.

### `list_acw_providers`

```python
def list_acw_providers() -> list[str]
```

Re-export of `agentize.workflow.utils.acw.list_acw_providers`.

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

Re-export of `agentize.workflow.utils.acw.ACW`.

## Internal Helpers

This module only re-exports selected helpers and does not define its own internal
implementation.

## Design Rationale

- **Stable imports**: A single import path keeps workflow code and tests stable while
  the helper modules remain organized under a package.
- **Focused surface**: Re-exports stay limited to the ACW helpers to avoid accidental
  coupling to internal convenience utilities.
