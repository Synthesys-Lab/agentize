# Module: agentize.workflow.simp

Public exports for the Python `lol simp` workflow.

## Exports

### `run_simp_workflow`

```python
def run_simp_workflow(
    file_path: str | None,
    *,
    backend: str = "codex:gpt-5.2-codex",
    max_files: int = 3,
    seed: int | None = None,
) -> None
```

Entry point for running the semantic-preserving simplifier. See `simp.md` for
full behavior and artifact outputs.

### `SimpError`

```python
class SimpError(RuntimeError):
    ...
```

Raised for workflow failures such as invalid file paths, git selection errors,
or prompt execution failures.
