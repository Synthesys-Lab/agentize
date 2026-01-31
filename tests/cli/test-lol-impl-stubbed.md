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
3. Precedence of `finalize.txt` over `report.txt`
4. Fallback to `report.txt` when `finalize.txt` absent
5. Max iterations limit enforcement
6. Backend parsing and provider/model split
7. `--yolo` flag passthrough
8. Issue prefetch success
9. Issue prefetch failure handling
10. Git commit after iteration when changes exist
11. Skip commit when no changes
12. Per-iteration commit report file
13. Missing commit report detection
14. Push remote precedence (upstream over origin)
15. Base branch selection (master over main)
16. Fallback to origin and main when upstream/master unavailable

## Usage

Run via the standard test runner; sources `tests/common.sh` for shared setup.
