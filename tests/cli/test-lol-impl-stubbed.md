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

1. Invalid backend format detection
2. Completion marker detection via `finalize.txt`
3. Max iterations limit enforcement
4. Backend parsing and provider/model split
5. `--yolo` flag passthrough
6. Issue prefetch success
7. Issue prefetch failure handling
8. Git commit after iteration when changes exist
9. Skip commit when no changes
10. Per-iteration commit report file
11. Missing commit report detection
12. Push remote precedence (upstream over origin)
13. Base branch selection (master over main)
14. Fallback to origin and main when upstream/master unavailable
15. PR body closes-line deduplication when already present
16. PR body closes-line append when missing
17. Sync fetch/rebase ordering before iterations
18. Sync rebase uses upstream/master
19. Sync rebase falls back to origin/main
20. Sync fetch failure handling
21. Sync rebase conflict handling

## Usage

Run via the standard test runner; sources `tests/common.sh` for shared setup.
