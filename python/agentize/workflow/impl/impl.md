# impl.py

Python workflow implementation for `lol impl`.

## Architecture Overview

The implementation follows a modular kernel-based architecture with:

1. **Orchestrator** (`run_impl_workflow()`): State machine that coordinates stages
2. **Kernels** (`kernels.py`): Pure functions for each workflow stage
3. **Checkpoint** (`checkpoint.py`): Serializable state for resumption

This design separates concerns:
- Orchestrator handles flow control and state transitions
- Kernels encapsulate stage-specific logic and are testable in isolation
- Checkpoint enables recovery from interruptions

The runtime loop is explicit and stage-driven:
`impl -> review -> simp -> pr -> (rebase?) -> finish`, with deterministic `fatal`
convergence for retry-limit and invalid-state failures.

## External Interface

### run_impl_workflow()

```python
def run_impl_workflow(
    issue_no: int,
    *,
    backend: str | None = None,
    max_iterations: int = 10,
    max_reviews: int = 8,
    yolo: bool = False,
    wait_for_ci: bool = False,
    resume: bool = False,
    impl_model: str | None = None,
    review_model: str | None = None,
    enable_review: bool = False,
    enable_simp: bool = False,
) -> None
```

**Purpose**: Execute the issue-to-implementation workflow with review loop
and checkpoint recovery.

**Parameters**:
- `issue_no`: Numeric issue identifier.
- `backend`: Deprecated, use `impl_model` instead.
- `max_iterations`: Maximum implementation iterations before failing.
- `max_reviews`: Maximum review attempts per iteration (prevents infinite loops).
- `yolo`: Pass-through flag for `acw` autonomy.
- `wait_for_ci`: When true, monitor PR mergeability and CI checks after creation.
- `resume`: When true, resume from last checkpoint if available.
- `impl_model`: Model for implementation stage (`provider:model` format).
- `review_model`: Optional different model for review stage.
- `enable_review`: Enable the review stage (default: False for compatibility).
- `enable_simp`: Enable the simplification stage (default: False).

**Workflow Stages**:

1. **Setup**: Resolve/create worktree, sync branch, prefetch issue
2. **Impl**: Generate implementation using AI
3. **Review**: Validate implementation quality (feedback loop on failure)
4. **Simp**: Evaluate code simplicity (optional, feedback loop on failure)
5. **PR**: Create pull request with explicit pass/fail event split
6. **Rebase**: Recover from non-fast-forward push/PR conflicts when possible

**State Machine**:

```mermaid
flowchart LR
    setup[setup] --> impl[impl]
    impl -->|impl_not_done| impl
    impl -->|parse_fail| impl
    impl -->|max iterations| fatal[fatal]
    impl --> review[review]
    review -->|passed| simp[simp]
    review -->|failed| impl
    review -->|4x no improvement| fatal
    simp -->|simp_pass| pr[pr]
    simp -->|simp_fail| impl
    pr -->|pr_pass| done[done]
    pr -->|pr_fail_fixable| impl
    pr -->|pr_fail_need_rebase| rebase[rebase]
    pr -->|6x failures| fatal
    rebase -->|rebase_ok| review
    rebase -->|rebase_conflict| fatal
```

**Checkpointing**:
- State is saved after each stage completion
- Use `--resume` to continue from last checkpoint
- Checkpoints stored in `.tmp/impl-checkpoint.json`

**Behavior**:
- Resolves the issue worktree via `wt pathto`, spawning with `wt spawn --no-agent` if needed.
- Syncs the issue branch by fetching and rebasing onto the detected default branch.
- Prefetches issue content via `agentize.workflow.api.gh` into `.tmp/issue-<N>.md`.
- Runs implementation iterations through `impl_kernel()`.
- Runs deterministic parse gate (`python -m py_compile`) on latest committed
  changed Python files before advancing to `review`/`pr`.
- Validates implementation through `review_kernel()` with feedback loop.
- Creates PR through `pr_kernel()` with explicit event contract:
  `pr_pass`, `pr_fail_fixable`, `pr_fail_need_rebase`.
- Runs `rebase_kernel()` on `pr_fail_need_rebase` and routes by
  `rebase_ok` / `rebase_conflict`.
- Optionally monitors CI and re-implements on failures when `wait_for_ci=True`.

**Retry limits and convergence guards**:
- `max_iterations` bounds impl attempts.
- `max_reviews` bounds review attempts in one iteration.
- PR attempts hard-limited to 6.
- Rebase attempts hard-limited to 3.
- Consecutive parse failures >= 3 force `fatal`.
- Consecutive non-improving review failures >= 4 force `fatal`.
- Simplification attempts hard-limited to 3 (global lifetime cap).

**CI Monitoring** (`wait_for_ci=True`):
After PR creation, monitors mergeability and CI checks:
1. Polls PR merge state via `gh pr view` until mergeable
2. If `CONFLICTING`, auto-rebases and force-pushes
3. Waits for CI checks via `gh pr checks --watch`
4. On CI failure, runs additional implementation iteration with failure context
5. Pushes fix and repeats monitoring
6. Stops after `max_iterations` total iterations (including CI fix iterations)

**Errors**:
- Raises `ValueError` for invalid arguments.
- Raises `ImplError` for workflow failures (sync, checkpoint, kernel errors).

## Internal Architecture

### State Management

The orchestrator uses `ImplState` from `checkpoint.py` to track:
- Current stage and iteration
- Last feedback and score
- Execution history

### Kernel Integration

The orchestrator dispatches to stage kernels via `run_fsm_orchestrator()`:

```python
context = WorkflowContext(plan="", upstream_instruction="", data={
    "impl_state": state, "session": session, ...
})
run_fsm_orchestrator(
    context,
    kernels=KERNELS,
    pre_step_hook=lambda ctx: save_checkpoint(ctx.data["impl_state"], checkpoint_path),
)
```

Each stage kernel extracts dependencies from `context.data`, calls the production
kernel, and returns a `StageResult` with the appropriate event. The transition table
determines the next stage.

### Backward Compatibility

The refactored implementation maintains backward compatibility:
- `_validate_pr_title()` remains at original location for imports
- CLI arguments `--backend` and `--max-iterations` work with deprecation warnings
- Return values and error types unchanged

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
- `.tmp/parse-iter-<N>.json`: Parse gate report for each completion attempt
- `.tmp/review-iter-<N>.json`: Structured review score report for each review attempt
- `.tmp/pr-iter-<N>.json`: Structured PR stage outcome artifact
- `.tmp/rebase-iter-<N>.json`: Structured rebase stage outcome artifact
- `.tmp/fatal-<timestamp>.json`: Terminal diagnostic artifact for fatal convergence
- `.tmp/finalize.txt`: Completion marker and PR title/body
- `.tmp/impl-checkpoint.json`: Workflow state for resumption

## Internal Helpers

### _validate_pr_title()

Validates PR title format `[tag][#N] description`.

**Location**: Kept in `impl.py` for backward compatibility with imports.

**Raises**: `ImplError` if format is invalid.

### rel_path()

Resolves template files relative to `impl.py` for portability.

### render_prompt()

Builds the iteration prompt by filling placeholders and conditionally inserting
previous output and commit summaries.

### _sync_branch()

Fetches the detected push remote and rebases onto the detected base branch.

### _prefetch_issue()

Fetches issue content via GitHub CLI and caches to file.

## Module Organization

```mermaid
flowchart LR
    subgraph ModuleStructure["python/agentize/workflow/impl/"]
        direction TB
        init["__init__.py<br/>Public exports"]
        main["__main__.py<br/>CLI entrypoint"]
        impl["impl.py<br/>Orchestrator"]
        impl_md["impl.md<br/>Documentation"]
        kernels["kernels.py<br/>Stage kernels"]
        kernels_md["kernels.md<br/>Kernel docs"]
        chk["checkpoint.py<br/>State management"]
        chk_md["checkpoint.md<br/>Checkpoint docs"]
        prompt["continue-prompt.md<br/>Prompt template"]
    end
```

See `kernels.md` for kernel function documentation.
See `checkpoint.md` for state and checkpoint documentation.
