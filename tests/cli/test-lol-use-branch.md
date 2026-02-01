# test-lol-use-branch.sh

Validates `lol use-branch` argument handling and branch switching workflow.

## Coverage

- Missing-argument handling with usage guidance.
- Dirty worktree guard prevents branch switching.
- Shorthand `<branch>` defaults to the `origin` remote.
- Remote branch checkout creates a local tracking branch and sets upstream.
- `make setup` runs and emits reload instructions.
