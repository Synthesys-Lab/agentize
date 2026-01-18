# Workers Module Documentation

## Overview

The `workers.py` module manages spawning and cleanup of Claude sessions for refinement and feature request planning tasks. It handles worktree management, process spawning, and worker status tracking.

## spawn_refinement and spawn_feat_request

### Planning on Main Branch

Both `spawn_refinement()` and `spawn_feat_request()` functions run planning sessions on the main branch worktree. This is critical to avoid worktree conflicts:

- **Main worktree location**: `.git/trees/main/`
- **Planning process**: The Claude session is launched with `cwd=worktree_path` pointing to the main worktree
- **Why**: Planning on an issue-specific worktree can cause conflicts in subsequent refinement steps when worktrees are reused

The functions follow this sequence:
1. Get the main worktree path using `wt pathto main` (not `wt pathto {issue_no}`)
2. Spawn Claude with the planning command in the main worktree directory
3. Return the spawned process ID for monitoring

## Cleanup Functions

### _cleanup_refinement()

Called after a refinement session completes. Responsibilities:
- Remove the `agentize:refine` label from the issue
- Reset issue status to "Proposed" on the GitHub Projects board
- Best-effort pattern: failures do not block cleanup completion

### _cleanup_feat_request()

Called after a feature request planning session completes. Responsibilities:
- Remove the `agentize:dev-req` label from the issue
- Reset issue status to "Proposed" on the GitHub Projects board
- Best-effort pattern: failures do not block cleanup completion

### Status Reset Behavior

After both cleanup functions remove their respective labels, they attempt to reset the issue status to "Proposed" using:

```bash
wt_claim_issue_status {issue_no} "{worktree_path}" Proposed
```

This operation is best-effort: if the status reset fails, the failure is logged by `wt_claim_issue_status` but does not raise an exception or prevent other cleanup steps from completing.

## Best-Effort Pattern

The best-effort pattern is used for status operations that should not block critical cleanup:

- **Status claims**: Using `wt_claim_issue_status()` for status updates
- **Behavior**: Call the function with `capture_output=True`, discard the result
- **Error handling**: No exception checking; failures are logged by the called function
- **Intent**: Ensures the core cleanup (label removal) always completes, even if status updates fail

This pattern is appropriate because:
- Status updates are informational, not critical to workflow correctness
- Label removal is the critical operation that must always succeed
- Network or permission errors should not prevent cleanup completion
