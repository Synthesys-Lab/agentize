# simp.sh

Delegates `lol simp` to the Python simplifier workflow in
`python/agentize/workflow/simp`.

## External Interface

### Command

```bash
lol simp [file] [--issue <issue-no>]
```

**Parameters**:
- `file`: Optional path to a file to simplify.
- `--issue <issue-no>`: Optional issue number to publish the report when approved.

**Behavior**:
- Delegates to the Python workflow via `python -m agentize.cli simp`.
- When `file` is omitted, the workflow selects a small random set of tracked
  files and records the selection in `.tmp/simp-targets.txt`.
- Writes prompt and output artifacts under `.tmp/`.
- Requires the simplification report to start with `Yes.` or `No.`.
- When `--issue` is provided and the report starts with `Yes.`, the report is
  published to the target issue.

**Failure conditions**:
- Invalid file path (missing, non-file, or outside the repo) reported by the
  Python workflow.
- Backend failures during prompt execution.

## Internal Helpers

### _lol_cmd_simp()
Private entrypoint that validates the optional file argument and delegates to
`python -m agentize.cli simp`.
