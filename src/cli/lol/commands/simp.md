# simp.sh

Delegates `lol simp` to the Python simplifier workflow in
`python/agentize/workflow/simp`.

## External Interface

### Command

```bash
lol simp [file] [<description>]
lol simp [file] --focus "<description>"
lol simp [file] --editor
```

**Parameters**:
- `file`: Optional path to a file to simplify.
- `description`: Optional focus text (positional, `--focus`, or `--editor`).
- `--focus <description>`: Optional focus description to guide simplification.
- `--editor`: Open `$EDITOR` to compose focus description.
- `--issue <issue-no>`: Optional issue number to publish the report when approved.

**Behavior**:
- Delegates to the Python workflow via `python -m agentize.cli simp`.
- When `file` is omitted, the workflow selects a small random set of tracked
  files and records the selection in `.tmp/simp-targets.txt`.
- When a single positional argument is provided, it is treated as a file if it
  exists; otherwise it is treated as the focus description.
- Writes prompt and output artifacts under `.tmp/`.
- Requires the simplification report to start with `Yes.` or `No.`.
- When `--issue` is provided and the report starts with `Yes.`, the report is
  published to the target issue.

**Failure conditions**:
- Invalid file path (missing, non-file, or outside the repo) reported by the
  Python workflow.
- Backend failures during prompt execution.
- Empty focus from `--editor` or missing `$EDITOR` environment variable.

## Internal Helpers

### _lol_cmd_simp()
Private entrypoint that validates the optional file argument and focus
description, then delegates to `python -m agentize.cli simp`.
