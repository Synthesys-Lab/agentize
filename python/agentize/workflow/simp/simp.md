# simp.py

Python workflow implementation for `lol simp`.

## External Interface

### run_simp_workflow()

```python
def run_simp_workflow(
    file_path: str | None,
    *,
    backend: str = "codex:gpt-5.2-codex",
    max_files: int = 3,
    seed: int | None = None,
    issue_number: int | None = None,
    focus: str | None = None,
) -> None
```

**Purpose**: Execute a semantic-preserving simplification pass over one or more
files using a prompt-driven workflow.

**Parameters**:
- `file_path`: Optional path to a specific file to simplify.
- `backend`: Backend in `provider:model` form.
- `max_files`: Maximum number of files to pick when `file_path` is omitted.
- `seed`: Optional random seed for file selection.
- `issue_number`: Optional issue number to publish the report when approved.
- `focus`: Optional focus description to guide simplification.

**Behavior**:
- Resolves the repo root and `.tmp/` output directory.
- Normalizes `file_path` to a repo-relative file and validates it exists.
- When `file_path` is omitted, runs `git ls-files`, shuffles the list with the
  optional seed, and selects up to `max_files` entries.
- Writes the selected file list to `.tmp/simp-targets.txt`.
- Renders `prompt.md` with the selected file list and file contents.
- Executes a single `Session.run_prompt()` call to produce `.tmp/simp-output.md`.
- Validates the report starts with `Yes.` or `No.` and logs the local report path.
- When the report starts with `Yes.` and `issue_number` is provided, publishes
  the report body to the matching GitHub issue.

**Errors**:
- Raises `ValueError` for invalid backend format, max file count, seed values,
  or issue number.
- Raises `SimpError` for missing files, git listing failures, or prompt execution errors.

## Prompt Template

`prompt.md` is a file-based prompt template. The renderer replaces:
- `{{focus_block}}`: Optional focus section (includes "Focus:" header and description when provided, empty string otherwise).
- `{{selected_files}}`: Newline list of the selected repo-relative file paths.
- `{{file_contents}}`: Markdown-formatted code blocks for each selected file.

## Outputs

- `.tmp/simp-input.md`: Rendered prompt input
- `.tmp/simp-output.md`: Simplification report (starts with `Yes.` or `No.`)
- `.tmp/simp-targets.txt`: Selected file list for reproducibility

## Internal Helpers

### rel_path()
Resolves template files relative to `simp.py` using `api.path.relpath`.

### _select_files()
Normalizes an explicit file path or selects a randomized subset from
`git ls-files`, respecting `max_files` and `seed`.

### _render_prompt()
Builds the prompt with file lists and file contents using `prompt.render`.
