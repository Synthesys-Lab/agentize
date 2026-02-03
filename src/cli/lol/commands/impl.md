# impl.sh

Delegates `lol impl` to the Python workflow in `python/agentize/workflow/impl`.

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
- Delegates to the Python workflow, which resolves worktrees, syncs the issue branch, runs the shared `ACW` runner, and manages git/PR automation.
- Syncs the issue branch by fetching and rebasing onto the default branch before starting iterations.
- Prefetches issue content via `gh issue view`; if it fails or returns empty content, the command exits with an error.
- Iterates `acw` runs, requiring a per-iteration commit report file in `.tmp/commit-report-iter-<iter>.txt`.
- Stages and commits changes each iteration when there are staged diffs.
- Detects completion via `.tmp/finalize.txt` when it contains `Issue <no> resolved`.
- Pushes the branch to a detected remote and opens a PR using the completion file contents.

**Outputs**:
- Progress and warnings to stderr/stdout.
- Creates/updates files under the worktree `.tmp/` directory.

**Failure conditions**:
- Invalid arguments (non-numeric issue or malformed backend).
- Sync failures (missing remote/default branch, fetch failure, or rebase conflict).
- Missing per-iteration commit report file.
- Max-iteration limit reached without a completion marker.
- Missing git remote or base branch for PR creation.

## Internal Helpers

### _lol_cmd_impl()
Private entrypoint function for the command implementation. It validates arguments and delegates to `python -m agentize.cli impl`.

### Worktree resolution
- Uses `wt pathto`/`wt spawn` to ensure a worktree exists for the issue.

### Issue prefetch
- Writes `.tmp/issue-<issue>.md` when `gh issue view` succeeds.
- Exits with an error when prefetch fails or produces empty content.

### Iteration loop
- Builds `.tmp/impl-input-<iter>.txt` from the base prompt plus previous output.
- Invokes the shared `ACW` runner (provider validation + timing logs) with provider/model plus optional `--yolo`.
- Requires `.tmp/commit-report-iter-<iter>.txt` and commits changes when present.

### Completion detection and PR creation
- Uses `.tmp/finalize.txt` for completion detection.
- Uses the completion file first line for PR title and full file as PR body.
- Appends `Closes #<issue>` only when a closes line is not already present (case-insensitive).
