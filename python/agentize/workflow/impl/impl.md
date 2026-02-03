# impl.py

Python workflow implementation for `lol impl`.

## External Interface

### run_impl_workflow()

```python
def run_impl_workflow(
    issue_no: int,
    *,
    backend: str = "codex:gpt-5.2-codex",
    max_iterations: int = 10,
    yolo: bool = False,
) -> None
```

**Purpose**: Execute the issue-to-implementation loop for a GitHub issue, driving
`acw` iterations and automating git/PR steps while keeping shell tools as the
source of truth.

**Parameters**:
- `issue_no`: Numeric issue identifier.
- `backend`: Backend in `provider:model` form.
- `max_iterations`: Maximum number of iterations before failing.
- `yolo`: Pass-through flag for `acw` autonomy.

**Behavior**:
- Resolves the issue worktree via `wt pathto`, spawning with `wt spawn --no-agent` if needed.
- Syncs the issue branch by fetching and rebasing onto the detected default branch before iterations.
- Prefetches issue content via `gh issue view` into `.tmp/issue-<N>.md`; fails if empty.
- Renders iteration prompts from `continue-prompt.md` into `.tmp/impl-input-<N>.txt`.
- Runs the shared `ACW` runner (provider validation + timing logs) and captures output in `.tmp/impl-output.txt`.
- Requires `.tmp/commit-report-iter-<N>.txt` for commits; stages and commits when diffs exist.
- Detects completion via `.tmp/finalize.txt` containing `Issue <N> resolved`.
- Pushes the branch and opens a PR using the completion file as title/body.

**Errors**:
- Raises `ValueError` for invalid arguments (issue number, backend format, max iterations).
- Raises `ImplError` for sync failures (missing remote/default branch, fetch failure, or rebase conflict),
  prefetch failures, missing commit reports, missing remotes/base branches, or max-iteration exhaustion.

## Prompt Template

`continue-prompt.md` is a file-based prompt template. The renderer replaces
placeholder tokens and splices optional sections.

**Required placeholders**:
- `{{issue_no}}`
- `{{issue_file}}`
- `{{finalize_file}}`
- `{{iteration_section}}`
- `{{previous_output_section}}`
- `{{previous_commit_report_section}}`

## Outputs

- `.tmp/issue-<N>.md`: Prefetched issue content
- `.tmp/impl-input-base.txt`: Base prompt instructions
- `.tmp/impl-input-<N>.txt`: Iteration-specific prompt
- `.tmp/impl-output.txt`: Latest `acw` output
- `.tmp/finalize.txt`: Completion marker and PR title/body

## Internal Helpers

### rel_path()
Resolves template files relative to `impl.py` for portability.

### render_prompt()
Builds the iteration prompt by filling placeholders and conditionally inserting
previous output and commit summaries.

### _detect_push_remote()
Selects `upstream` when available, falling back to `origin`.

### _detect_base_branch()
Selects `master` when available on the push remote, falling back to `main`.

### _sync_branch()
Fetches the detected push remote and rebases onto the detected base branch, failing fast on errors.
