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
    wait_for_ci: bool = False,
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
- `wait_for_ci`: When true, monitor PR mergeability and CI checks after creation.

**Behavior**:
- Resolves the issue worktree via `wt pathto`, spawning with `wt spawn --no-agent` if needed.
- Syncs the issue branch by fetching and rebasing onto the detected default branch before iterations.
- Prefetches issue content via `agentize.workflow.api.gh` into `.tmp/issue-<N>.md`; fails if empty.
- Renders iteration prompts from `continue-prompt.md` into `.tmp/impl-input-<N>.txt`
  via `agentize.workflow.api.prompt.render`.
- Runs iterations through `Session.run_prompt()` with input/output path overrides to reuse
  `.tmp/impl-output.txt` across iterations.
- Requires `.tmp/commit-report-iter-<N>.txt` for commits; stages and commits when diffs exist.
- Detects completion via `.tmp/finalize.txt` containing `Issue <N> resolved`.
- Pushes the branch and opens a PR using the completion file as title/body.
- Optionally waits for PR mergeability and CI completion, reusing the iteration loop to fix failures.

**Post-PR phase** (when `wait_for_ci` is enabled):
- Checks PR mergeability and rebases the branch when conflicts are detected.
- Runs `gh pr checks --watch` to stream CI progress.
- On CI failures, reruns an iteration with CI context injected into the prompt and pushes updates.

**Errors**:
- Raises `ValueError` for invalid arguments (issue number, backend format, max iterations).
- Raises `ImplError` for sync failures (missing remote/default branch, fetch failure, or rebase conflict),
  prefetch failures, missing commit reports, missing remotes/base branches, or max-iteration exhaustion.

## Prompt Template

`continue-prompt.md` is a file-based prompt template. The renderer replaces
placeholder tokens and splices optional sections.

The prompt includes explicit instructions for PR title format. The first line
of `finalize_file` is used as the PR title and must follow the format:
`[tag][#issue-number] Brief description`. Available tags are defined in
`docs/git-msg-tags.md`.

**Required placeholders** (both `{{TOKEN}}` and `{#TOKEN#}` forms are accepted):
- `issue_no`
- `issue_file`
- `finalize_file`
- `iteration_section`
- `previous_output_section`
- `previous_commit_report_section`
- `ci_failure_section`

## Outputs

- `.tmp/issue-<N>.md`: Prefetched issue content
- `.tmp/impl-input-base.txt`: Base prompt instructions
- `.tmp/impl-input-<N>.txt`: Iteration-specific prompt
- `.tmp/impl-output.txt`: Latest `acw` output
- `.tmp/finalize.txt`: Completion marker and PR title/body

## Internal Helpers

### rel_path()
Resolves template files relative to `impl.py` for portability using `api.path.relpath`.

### render_prompt()
Builds the iteration prompt by filling placeholders and conditionally inserting
previous output and commit summaries, delegating token replacement to `prompt.render`.

### _detect_push_remote()
Selects `upstream` when available, falling back to `origin`.

### _detect_base_branch()
Selects `master` when available on the push remote, falling back to `main`.

### _sync_branch()
Fetches the detected push remote and rebases onto the detected base branch, failing fast on errors.
