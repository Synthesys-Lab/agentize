# tests/cli/test-lol-impl-stubbed.sh

## Purpose

Validate `lol impl` behavior with deterministic stubs for external tools.

## Stubs

- `git`: Simulate repository interactions (add, diff, commit, remote, fetch, rebase, push)
- `wt`: Return predictable worktree paths
- `acw`: Return canned planner/impl outputs
- `gh`: Return mocked issue data and PR creation responses

Stubs are defined in a shell override script referenced by `AGENTIZE_SHELL_OVERRIDES`. This ensures the Python workflow (invoked in a subprocess) uses the same stubbed `wt`, `acw`, `gh`, and `git` functions.

## Test Cases

1. Backend format validation (`--backend provider:model`)
2. Issue prefetch success and failure handling (`.tmp/issue-<N>.md`)
3. Completion marker detection via `.tmp/finalize.txt`
4. Per-iteration commit report requirement (`.tmp/commit-report-iter-<N>.txt`)
5. Sync fetch + rebase error handling (conflict/failure) before iterations
6. Base branch + remote selection (upstream/master fallback to origin/main)
7. Post-PR monitoring (`--wait-for-ci`) triggers mergeability checks + CI watch
8. Auto-rebase on conflicting PRs (force-push after rebase)
9. CI failure triggers a follow-up iteration with new commit

## Usage

Run via the standard test runner; sources `tests/common.sh` for shared setup.
