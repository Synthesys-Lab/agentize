# __main__.py

CLI entrypoint for `python -m agentize.workflow.impl`.

## External Interfaces

### `main()`

```python
def main(argv: list[str]) -> int
```

Parses CLI arguments and runs `run_impl_workflow()` with the selected backend, maximum
iteration count, and optional `--yolo` flag. Returns a process exit code.

## Internal Helpers

This module delegates all workflow behavior to `impl.run_impl_workflow` and does not
define internal helpers.

## Design Rationale

- **Thin CLI wrapper**: A dedicated `__main__` keeps CLI parsing separate from the core
  workflow logic while preserving a clean `python -m` entrypoint.
