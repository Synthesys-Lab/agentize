# path.py

Path helpers for workflow modules.

## External Interfaces

### `relpath`

```python
def relpath(from_file: str | Path, *parts: str | Path) -> Path
```

Resolves an absolute path by joining `parts` relative to the directory containing
`from_file`. If any `parts` entry is absolute, it is returned as-is.

## Internal Helpers

This module has no internal helpers.

## Design Rationale

- **Portable module paths**: Resolving paths from a module file keeps prompt templates
  and assets discoverable regardless of the current working directory.
