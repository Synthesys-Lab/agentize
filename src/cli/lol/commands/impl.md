# impl.sh

Implements `lol impl`, the issue-to-implementation loop that drives `acw` iterations, git commits, and PR creation.

## External Interface

### Command

```bash
lol impl <issue-no> [--backend <provider:model>] [--max-iterations <N>] [--yolo]
```

**Parameters**:
- `issue-no`: Numeric issue identifier.
- `--backend`: Backend in `provider:model` form (default: `codex:gpt-5.2-codex`).
- `--max-iterations`: Maximum number of `acw` iterations (default: `10`).
- `--yolo`: Pass-through flag to `acw` for autonomous actions.

**Behavior**:
- Ensures a worktree exists for the issue, then switches into it.
- Prefetches issue content via `gh issue view`; if it fails, the command exits with an error.
- Iterates `acw` runs, requiring a per-iteration commit report file in `.tmp/commit-report-iter-<iter>.txt`.
- Stages and commits changes each iteration when there are staged diffs.
- Detects completion via `.tmp/finalize.txt` when it contains `Issue <no> resolved`.
- Pushes the branch to a detected remote and opens a PR using the completion file contents.

**Outputs**:
- Progress and warnings to stderr/stdout.
- Creates/updates files under the worktree `.tmp/` directory.

**Failure conditions**:
- Invalid arguments (non-numeric issue or malformed backend).
- Missing per-iteration commit report file.
- Max-iteration limit reached without a completion marker.
- Missing git remote or base branch for PR creation.

## Internal Helpers

### _lol_cmd_impl()
Private entrypoint function for the command implementation. It validates arguments and orchestrates the issue-to-implementation loop described above.

### Worktree resolution
- Uses `wt pathto`/`wt spawn`/`wt goto` to ensure a worktree exists for the issue.

### Issue prefetch
- Writes `.tmp/issue-<issue>.md` when `gh issue view` succeeds.
- Falls back to a minimal prompt when prefetch fails or produces empty content.

### Iteration loop
- Builds `.tmp/impl-input-<iter>.txt` from the base prompt plus previous output.
- Invokes `acw` with provider/model plus optional `--yolo`.
- Requires `.tmp/commit-report-iter-<iter>.txt` and commits changes when present.

### Completion detection and PR creation
- Uses `.tmp/finalize.txt` for completion detection.
- Uses the completion file first line for PR title and full file as PR body.
