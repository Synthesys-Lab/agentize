# checkpoint.py

Checkpoint save/restore for the `lol impl` workflow.

## Design Overview

Checkpointing enables workflow resumption after interruptions. The state is
serialized to JSON after each stage completion, allowing the orchestrator to
resume from the last successful checkpoint.

## ImplState

```python
@dataclass
class ImplState:
    """Serializable workflow state for checkpointing."""
    
    issue_no: int
    current_stage: Literal["impl", "review", "simp", "pr", "done"]
    iteration: int
    worktree: Path
    plan_file: Path | None
    last_feedback: str
    last_score: int
    history: list[dict]
```

### Fields

**issue_no**: int
The GitHub issue number being implemented.

**current_stage**: Literal["impl", "review", "simp", "pr", "done"]
The current workflow stage. One of:
- `impl`: Implementation generation stage
- `review`: Quality review stage
- `simp`: Simplification stage
- `pr`: Pull request creation stage
- `done`: Workflow completed

**iteration**: int
Current iteration count (1-based). Increments after each impl/review cycle.

**worktree**: Path
Absolute path to the git worktree for this issue.

**plan_file**: Path | None
Optional path to the implementation plan file (if available).

**last_feedback**: str
Feedback from the last stage execution. Used for context in next iteration.

**last_score**: int
Quality score from last review (0-100). Used to determine pass/fail.

**history**: list[dict]
List of completed stage executions. Each entry contains:
```python
{
    "stage": str,        # Stage name
    "iteration": int,    # Iteration number
    "timestamp": str,    # ISO format timestamp
    "result": str,       # "success", "failure", "retry"
    "score": int | None, # Quality score if applicable
}
```

## Checkpoint Format

Checkpoints are stored as JSON files with the following structure:

```json
{
  "version": 1,
  "timestamp": "2025-01-15T10:30:00",
  "state": {
    "issue_no": 42,
    "current_stage": "review",
    "iteration": 3,
    "worktree": "/path/to/worktree",
    "plan_file": "/path/to/plan.md",
    "last_feedback": "Implementation looks good but needs more tests",
    "last_score": 75,
    "history": [
      {
        "stage": "impl",
        "iteration": 1,
        "timestamp": "2025-01-15T10:00:00",
        "result": "success",
        "score": null
      },
      {
        "stage": "review",
        "iteration": 1,
        "timestamp": "2025-01-15T10:15:00",
        "result": "retry",
        "score": 60
      }
    ]
  }
}
```

### Version Field

The `version` field enables future migration of checkpoint formats:
- Version 1: Initial format (current)

When loading, if version mismatch is detected, the loader may attempt
migration or raise an error.

## API

### save_checkpoint()

```python
def save_checkpoint(
    state: ImplState,
    checkpoint_path: Path,
) -> None
```

Save state to a checkpoint file.

**Parameters**:
- `state`: The state to save
- `checkpoint_path`: Path to write the checkpoint file

**Behavior**:
- Serializes state to JSON with pretty printing
- Adds version and timestamp metadata
- Creates parent directories if needed
- Uses atomic write (write to temp, then rename)

**Errors**:
- Raises `ImplError` if serialization fails
- Raises `OSError` for filesystem errors

### load_checkpoint()

```python
def load_checkpoint(checkpoint_path: Path) -> ImplState
```

Load state from a checkpoint file.

**Parameters**:
- `checkpoint_path`: Path to the checkpoint file

**Returns**:
- The loaded `ImplState` object

**Behavior**:
- Reads and parses JSON checkpoint
- Validates version compatibility
- Reconstructs `ImplState` with proper Path objects

**Errors**:
- Raises `ImplError` if file doesn't exist or is corrupted
- Raises `ImplError` if version is incompatible

### ImplState.save()

Instance method for saving state:

```python
def save(self, path: Path) -> None:
    """Save state to checkpoint file."""
```

Delegates to `save_checkpoint()`.

### ImplState.load()

Class method for loading state:

```python
@classmethod
def load(cls, path: Path) -> ImplState:
    """Load state from checkpoint file."""
```

Delegates to `load_checkpoint()`.

## Checkpoint Locations

By convention, checkpoints are stored in the issue worktree:

```
.tmp/impl-checkpoint.json
```

This location is used by:
- `save_checkpoint()` when called from the orchestrator
- `load_checkpoint()` when `--resume` flag is used

## Resumption Logic

When resuming from a checkpoint:

1. Load the checkpoint file
2. Validate worktree still exists
3. Set up session with same output directory
4. Jump to the `current_stage` in the state machine
5. Continue from the saved `iteration`

The orchestrator handles stage-specific resumption:
- If interrupted during `impl`, restart the iteration
- If interrupted after `review` but before using feedback, use saved feedback
- If interrupted during `pr`, check if PR already exists

## State Transitions

Valid state transitions in the workflow:

```
impl -> review -> simp -> pr -> done
 |       |       |       |
 +-------+       |       |
 (feedback loop) |       |
                 |       |
 (skip simp) ----+       |
                         |
 (skip if PR exists) ----+
```

The history field tracks the actual path taken through this graph.

## Concurrency

Checkpoints are written atomically (write to temp file, then rename)
to prevent corruption if the process is interrupted during write.

Multiple concurrent workflows on the same issue are not supported
and may result in checkpoint corruption.

## Cleanup

Checkpoints are not automatically deleted after workflow completion
to allow for debugging and audit trails. Users can manually remove:

```bash
rm .tmp/impl-checkpoint.json
```

Future versions may add automatic cleanup via a `--cleanup` flag.
