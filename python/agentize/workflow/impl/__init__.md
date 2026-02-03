# Module: agentize.workflow.impl

Public exports for the Python `lol impl` workflow.

## Exports

### `run_impl_workflow`

```python
def run_impl_workflow(
    issue_no: int,
    *,
    backend: str = "codex:gpt-5.2-codex",
    max_iterations: int = 10,
    yolo: bool = False,
) -> None
```

Entry point for running the issue-to-implementation loop. See `impl.md` for
full behavior and file outputs.

### `ImplError`

```python
class ImplError(RuntimeError):
    ...
```

Raised for workflow failures such as missing worktrees, prefetch errors, or
sync errors, prefetch errors, or max-iteration exhaustion.
