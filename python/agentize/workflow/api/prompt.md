# prompt.py

Prompt rendering helpers for workflow templates.

## External Interfaces

### `read_prompt`

```python
def read_prompt(path: str | Path, *, strip_frontmatter: bool = False) -> str
```

Reads a prompt file and optionally strips YAML frontmatter. Raises `FileNotFoundError`
when the path is missing.

### `render`

```python
def render(
    template_path: str | Path,
    values: dict[str, str],
    dest_path: str | Path,
    *,
    strip_frontmatter: bool = False,
) -> str
```

Renders a template by replacing both `{{TOKEN}}` and `{#TOKEN#}` placeholders for each
key in `values`, writes the result to `dest_path`, and returns the rendered content.

## Internal Helpers

### `_strip_yaml_frontmatter()`

Removes leading YAML frontmatter blocks delimited by `---`.

### `_replace_tokens()`

Performs token replacement for the supported placeholder formats.

## Design Rationale

- **Dual placeholder support**: Supporting both formats lets templates evolve without
  breaking existing prompt files.
- **File-centric workflow**: Reading and writing files preserves the CLI pipeline
  structure used by planner and impl workflows.
