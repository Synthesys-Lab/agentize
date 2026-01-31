# tests/cli/test-lol-plan-issue-mode.sh

## Purpose

Validate `lol plan` issue-mode flow with stubbed `gh` and `acw` responses.

## Stubs

- `gh`: Provides issue metadata used by planning (create, view, edit)
- `acw`: Returns deterministic plan output for each pipeline stage

Stubs remain local to the test shell to preserve bash/zsh compatibility.

## Test Cases

1. Default behavior creates issue (no `--dry-run`)
2. `--dry-run` skips issue creation
3. `--refine` uses issue-refine prefix and publishes
4. `--dry-run --refine` skips publish but keeps issue-refine prefix
5. Fallback when `gh` fails (default mode)

## Usage

Run via the standard test runner; sources `tests/common.sh` for shared setup.
