# use-branch.sh

Implements `lol use-branch` for switching the SDK worktree to a remote
development branch and rebuilding the environment.

## External Interface

### lol use-branch <remote>/<branch>
Fetches the remote branch, checks out (or creates) a local tracking branch,
runs `make setup`, and prints shell reload instructions.

### lol use-branch <branch>
Defaults the remote to `origin` and applies the same workflow as above.

**Exit codes**:
- 0 on success.
- 1 on validation failures (missing args, dirty worktree, unknown remote/branch,
  or setup failures).

## Internal Helpers

### _lol_cmd_use_branch()
Private entrypoint that validates the git worktree, ensures a clean state,
fetches the requested branch, checks it out with upstream tracking, runs
`make setup`, and emits reload guidance.
