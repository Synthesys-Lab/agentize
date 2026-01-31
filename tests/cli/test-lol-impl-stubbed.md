# tests/cli/test-lol-impl-stubbed.sh

## Purpose

Validate `lol impl` behavior with deterministic stubs for external tools.

## Stubs

- `git`: Simulate repository interactions (add, diff, commit, remote, push)
- `wt`: Return predictable worktree paths
- `acw`: Return canned planner/impl outputs
- `gh`: Return mocked issue data and PR creation responses

Stubs are defined in the test shell and used by sourced CLI code to keep behavior shell-neutral. No `export -f` is used since the CLI is sourced (not invoked as a subprocess).

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

## Usage

Run via the standard test runner; sources `tests/common.sh` for shared setup.
