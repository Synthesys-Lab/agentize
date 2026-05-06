# kernels.py

Kernel functions for the modular `lol impl` workflow.

## Design Overview

Kernels are pure functions that execute a single stage of the implementation
workflow. Each kernel receives an `ImplState` and a `Session`, performs its
work, and returns results in a consistent format. This design enables:

- **Testability**: Kernels can be unit tested with mock Session objects
- **Composability**: The orchestrator combines kernels in a state machine
- **Extensibility**: New stages can be added without modifying existing kernels

## Kernel Function Signature

All kernels follow a consistent signature pattern:

```python
def kernel_name(
    state: ImplState,
    session: Session,
    **kwargs
) -> tuple[...]:
    """
    Execute a workflow stage.
    
    Args:
        state: Current workflow state with all accumulated context
        session: Session for running AI prompts
        **kwargs: Stage-specific parameters
        
    Returns:
        Tuple of (primary_result, feedback/context, additional_data...)
    """
```

## Kernel Functions

### impl_kernel()

```python
def impl_kernel(
    state: ImplState,
    session: Session,
    *,
    template_path: Path,
    provider: str,
    model: str,
    yolo: bool = False,
    ci_failure: str | None = None,
) -> tuple[int, str, dict]
```

Execute implementation generation for the current iteration.

**Parameters**:
- `state`: Current workflow state
- `session`: Session for running prompts
- `template_path`: Path to the prompt template file
- `provider`: Model provider
- `model`: Model name
- `yolo`: Pass-through flag for ACW autonomy
- `ci_failure`: CI failure context for retry iterations

**Returns**:
- `score`: Self-assessed implementation quality (0-100)
- `feedback`: Summary of changes made
- `result`: Dict with `files_changed`, `completion_found` keys

**Behavior**:
- Renders the iteration prompt from template with state context
- Runs the prompt through Session
- Checks for completion marker in finalize file
- Requires commit report for staging/committing changes
- Returns self-assessed quality score from output parsing

**Errors**:
- Raises `ImplError` if commit report is missing when completion is found
- Raises `PipelineError` if ACW execution fails

### review_kernel()

```python
def review_kernel(
    state: ImplState,
    session: Session,
    *,
    provider: str,
    model: str,
) -> tuple[bool, str, int]
```

Review implementation quality and provide feedback.

**Parameters**:
- `state`: Current workflow state including last implementation
- `session`: Session for running prompts
- `provider`: Review model provider
- `model`: Review model name

**Returns**:
- `passed`: Whether implementation passes quality threshold
- `feedback`: Detailed feedback for re-implementation if failed
- `score`: Quality score from 0-100

**Behavior**:
- Analyzes the latest implementation output against issue requirements.
- Requests JSON-first review output with scores for:
  - `faithful`
  - `style`
  - `docs`
  - `corner_cases`
- Enforces deterministic thresholds:
  - `faithful >= 90`
  - `style >= 85`
  - `docs >= 85`
  - `corner_cases >= 85`
- Writes structured artifact: `.tmp/review-iter-{N}.json`
- Returns fail with retry feedback when any threshold is not met.

**Review Artifact** (`.tmp/review-iter-{N}.json`):
- `scores`: dimension score map
- `pass`: boolean gate result
- `findings`: reviewer findings list
- `suggestions`: actionable retry suggestions
- `raw_output_path`: source review text path

If review output is non-JSON, the kernel falls back to legacy textual score and
section parsing to keep the gate deterministic.

### simp_kernel()

```python
def simp_kernel(
    state: ImplState,
    session: Session,
    *,
    provider: str,
    model: str,
    max_files: int = 3,
) -> tuple[bool, str]
```

Simplify/refine the implementation.

**Parameters**:
- `state`: Current workflow state
- `session`: Session for running prompts (unused, kept for signature consistency)
- `provider`: Model provider
- `model`: Model name
- `max_files`: Maximum files to simplify at once

**Returns**:
- `passed`: Whether simplification succeeded
- `feedback`: Summary of simplifications made or errors

**Behavior**:
- Wrapper around existing simp workflow logic
- Runs simplification on current implementation
- Validates output maintains correctness
- Updates state with simplified result

**Note**:
This kernel is kept separate from the main `simp` workflow to allow
selective use within the impl workflow while maintaining the standalone
`simp` command for other use cases.

### pr_kernel()

```python
def pr_kernel(
    state: ImplState,
    session: Session | None,
    *,
    push_remote: str | None = None,
    base_branch: str | None = None,
) -> tuple[Event, str, str | None, str | None, Path]
```

Create pull request for the implementation.

**Parameters**:
- `state`: Current workflow state with finalize content
- `session`: Optional session (not used, kept for signature consistency)
- `push_remote`: Remote to push to (auto-detected if None)
- `base_branch`: Base branch for PR (auto-detected if None)

**Returns**:
- `event`: `pr_pass` / `pr_fail_fixable` / `pr_fail_need_rebase`
- `message`: Human-readable stage reason
- `pr_number`: PR number as string if created, None otherwise
- `pr_url`: Full PR URL if created, None otherwise
- `report_path`: Path to `.tmp/pr-iter-{N}.json`

**Behavior**:
- Validates PR title format using `_validate_pr_title()`
- Pushes branch to remote
- Creates PR using finalize file content
- Appends "Closes #N" line if not present
- Emits explicit event-based failures (`fixable` vs `need_rebase`)
- Writes structured artifact: `.tmp/pr-iter-{N}.json`

### rebase_kernel()

```python
def rebase_kernel(
    state: ImplState,
    *,
    push_remote: str | None = None,
    base_branch: str | None = None,
) -> tuple[Event, str, Path]
```

Rebase current branch onto detected base branch for PR recovery.

**Returns**:
- `event`: `rebase_ok` or `rebase_conflict`
- `message`: Stage reason for logs/retry context
- `report_path`: Path to `.tmp/rebase-iter-{N}.json`

**Behavior**:
- Runs `git fetch <remote>` before rebase.
- Runs `git rebase <remote>/<base>`.
- Calls `git rebase --abort` when conflict occurs.
- Writes structured artifact for deterministic diagnostics.

**Errors**:
- Raises `ImplError` if PR title format is invalid
- Returns `(False, message, None, None)` for non-fatal failures (e.g., PR already exists)

## Helper Functions

### _parse_quality_score()

Parse quality score from kernel output text.

```python
def _parse_quality_score(output: str) -> int:
```

Extracts a 0-100 score from output containing patterns like:
- "Score: 85/100"
- "Quality: 85"
- "Rating: 8.5/10"

Returns 50 (neutral) if no score found.

### _parse_completion_marker()

Check if output indicates workflow completion.

```python
def _parse_completion_marker(
    finalize_file: Path,
    issue_no: int,
) -> bool
```

Returns True if finalize file contains "Issue {N} resolved".

### run_parse_gate()

Run deterministic Python parse validation for the latest implementation
iteration before entering `review`/`pr`.

```python
def run_parse_gate(
    state: ImplState,
    *,
    files_changed: bool,
) -> tuple[bool, str, Path]
```

Behavior:
- Writes `.tmp/parse-iter-{N}.json` for every completion attempt.
- Detects Python files from the latest commit and runs:
  `python -m py_compile <files...>`.
- Returns pass/fail status, feedback message, and report path.
- On failure, report contains failed files, traceback, and suggestions for
  the next implementation retry.

## Output Format Conventions

Kernels should produce output that follows these conventions for
consistent parsing:

### Quality Score Format
```
Score: <number>/100
```

### Completion Marker Format
```
Issue <number> resolved
```

### Feedback Format
```
Feedback:
- <point 1>
- <point 2>
```

## Error Handling

Kernels handle errors at three levels:

1. **Fatal errors**: Raise `ImplError` for unrecoverable issues
2. **Retryable errors**: Let `Session.run_prompt()` handle retry logic
3. **Stage failures**: Return `(False, message, ...)` for graceful degradation

The orchestrator decides whether to retry, continue, or abort based on
kernel return values and the current state.

## FSM Stage Kernels

`kernels.py` exposes the production stage-handler registry:

- `impl_stage_kernel(context)`: Calls `impl_kernel()`, runs parse gate, tracks
  `parse_fail_streak`, emits `EVENT_IMPL_DONE`/`EVENT_IMPL_NOT_DONE`/`EVENT_PARSE_FAIL`/`EVENT_FATAL`
- `review_stage_kernel(context)`: Handles `enable_review=False` → `EVENT_REVIEW_PASS`,
  calls `review_kernel()`, tracks convergence via `review_fail_streak`, emits
  `EVENT_REVIEW_PASS`/`EVENT_REVIEW_FAIL`/`EVENT_FATAL`
- `pr_stage_kernel(context)`: Calls `pr_kernel()`, passes through event, tracks
  `pr_attempts` (limit 6), emits `EVENT_PR_PASS`/`EVENT_PR_FAIL_*`/`EVENT_FATAL`
- `rebase_stage_kernel(context)`: Calls `rebase_kernel()`, passes through event,
  tracks `rebase_attempts` (limit 3), resets `review_attempts`/`review_fail_streak`/`last_review_score`
  on `EVENT_REBASE_OK` (so review starts fresh after rebase), emits `EVENT_REBASE_OK`/`EVENT_REBASE_CONFLICT`/`EVENT_FATAL`
- `simp_stage_kernel(context)`: Handles `enable_simp=False` → `EVENT_SIMP_PASS`,
  calls `simp_kernel()`, tracks `simp_attempts` (limit 3), emits
  `EVENT_SIMP_PASS`/`EVENT_SIMP_FAIL`
- `KERNELS: dict[Stage, Callable[[WorkflowContext], StageResult]]`

Stage kernels extract `ImplState` and dependencies from `context.data` and mutate
`ImplState` directly for iteration, history, and feedback tracking.

## Stage Artifacts

- `.tmp/parse-iter-{N}.json`: Parse gate report
- `.tmp/review-iter-{N}.json`: Structured review scores and suggestions
- `.tmp/pr-iter-{N}.json`: PR stage event diagnostics
- `.tmp/rebase-iter-{N}.json`: Rebase stage event diagnostics
