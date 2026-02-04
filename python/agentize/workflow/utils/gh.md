# gh.py

GitHub CLI wrappers for workflow orchestration.

## External Interfaces

### `issue_create`

```python
def issue_create(
    title: str,
    body: str,
    labels: list[str] | None = None,
    *,
    cwd: str | Path | None = None,
) -> tuple[str | None, str]
```

Creates a GitHub issue with the provided title/body and optional labels.

**Returns**: `(issue_number, issue_url)` when the URL can be parsed; `issue_number` is
`None` if parsing fails but the URL is available.

**Raises**: `RuntimeError` when `gh` is unavailable or the CLI returns a failure.

### `pr_create`

```python
def pr_create(
    title: str,
    body: str,
    *,
    draft: bool = False,
    base: str | None = None,
    head: str | None = None,
    cwd: str | Path | None = None,
) -> str
```

Creates a pull request from the current branch and returns the PR URL.

**Raises**: `RuntimeError` when `gh` is unavailable or the CLI returns a failure.

### `label_create`

```python
def label_create(
    name: str,
    color: str,
    description: str = "",
    *,
    cwd: str | Path | None = None,
) -> None
```

Creates or updates a label with the given name, color, and description.

### `label_add`

```python
def label_add(
    issue_number: str | int,
    labels: list[str],
    *,
    cwd: str | Path | None = None,
) -> None
```

Adds one or more labels to an existing issue.

## Internal Helpers

### `_gh_available()`

Checks that `gh` is installed and authenticated.

### `_run_gh()`

Runs the `gh` CLI with `capture_output=True`, raising a `RuntimeError` on failure.

### `_resolve_overrides()`

Resolves `AGENTIZE_SHELL_OVERRIDES` when a workflow provides shell stubs for `gh`.

### `_body_args()`

Chooses between `--body` and `--body-file` based on whether the body includes
multiline content.

### `issue_body()`

Fetches the issue body for a numeric issue identifier.

### `issue_url()`

Fetches the issue URL for a numeric issue identifier.

### `issue_edit()`

Edits issue fields (title/body/labels) via `gh issue edit`.

## Design Rationale

- **Single point of failure handling**: All `gh` errors are raised with a clear
  runtime error so the caller can surface workflow failures early.
- **Portable repository context**: Every helper accepts `cwd` to ensure the correct
  repository context without relying on global state.
- **Stub-friendly execution**: When `AGENTIZE_SHELL_OVERRIDES` is present, `gh` calls
  are executed via a shell wrapper so workflow stubs can intercept CLI traffic.
- **Multiline-safe payloads**: Issue and PR bodies are passed via `--body-file` when
  content includes newlines to preserve formatting and avoid shell splitting.
