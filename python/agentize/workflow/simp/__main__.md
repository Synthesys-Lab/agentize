# __main__.py

CLI entrypoint for `python -m agentize.workflow.simp`.

## External Interfaces

### `main()`

```python
def main(argv: list[str]) -> int
```

Parses CLI arguments and runs `run_simp_workflow()` with backend, max file count,
optional random seed, optional target file, and optional focus description.
Returns a process exit code.

## Internal Helpers

This module delegates all workflow behavior to `simp.run_simp_workflow` and does
not define internal helpers.

## Design Rationale

- **Thin CLI wrapper**: Keeps CLI parsing separate from workflow logic while
  preserving a `python -m` entrypoint for scripting.
