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
    yolo: bool = False,
) -> tuple[int, str, dict]
```

Execute implementation generation for the current iteration.

**Parameters**:
- `state`: Current workflow state
- `session`: Session for running prompts
- `template_path`: Path to the prompt template file
- `yolo`: Pass-through flag for ACW autonomy

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
    review_template_path: Path | None = None,
    threshold: int = 70,
) -> tuple[bool, str, int]
```

Review implementation quality and provide feedback.

**Parameters**:
- `state`: Current workflow state including last implementation
- `session`: Session for running prompts
- `review_template_path`: Optional path to review prompt template
- `threshold`: Minimum score to pass review (default 70)

**Returns**:
- `passed`: Whether implementation passes quality threshold
- `feedback`: Detailed feedback for re-implementation if failed
- `score`: Quality score from 0-100

**Behavior**:
- Analyzes the last implementation output against the issue requirements
- Scores code quality, test coverage, documentation completeness
- Provides actionable feedback for improvements
- Can trigger re-implementation loop via orchestrator

**Review Criteria**:
- Code correctness and error handling
- Test coverage and quality
- Documentation completeness
- Adherence to project conventions
- Issue requirement fulfillment

### simp_kernel()

```python
def simp_kernel(
    state: ImplState,
    session: Session,
    *,
    simp_template_path: Path | None = None,
) -> tuple[bool, str]
```

Simplify/refine the implementation.

**Parameters**:
- `state`: Current workflow state
- `session`: Session for running prompts
- `simp_template_path`: Optional path to simp prompt template

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
) -> tuple[bool, str, str | None, str | None]
```

Create pull request for the implementation.

**Parameters**:
- `state`: Current workflow state with finalize content
- `session`: Optional session (not used, kept for signature consistency)
- `push_remote`: Remote to push to (auto-detected if None)
- `base_branch`: Base branch for PR (auto-detected if None)

**Returns**:
- `success`: Whether PR was created successfully
- `message`: PR URL on success, error message on failure
- `pr_number`: PR number as string if created, None otherwise
- `pr_url`: Full PR URL if created, None otherwise

**Behavior**:
- Validates PR title format using `_validate_pr_title()`
- Pushes branch to remote
- Creates PR using finalize file content
- Appends "Closes #N" line if not present
- Returns PR number and URL for downstream CI monitoring

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
