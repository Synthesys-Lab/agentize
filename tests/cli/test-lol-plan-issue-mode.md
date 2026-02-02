# tests/cli/test-lol-plan-issue-mode.sh

## Purpose

Validate `lol plan` issue-mode flow with stubbed `gh` and `acw` responses via the Python backend.

## Stubs

- `gh` CLI (PATH override): Logs issue create/view/edit calls and returns deterministic URLs.
- `acw` loader (`PLANNER_ACW_SCRIPT`): Writes stage outputs without invoking real models.
- `external-consensus.sh` (`_PLANNER_CONSENSUS_SCRIPT`): Produces a stable consensus file with an `Implementation Plan` header.

## Test Cases

1. Default behavior creates issue (no `--dry-run`).
2. `--dry-run` skips issue creation.
3. `--refine` uses issue-refine prefix and publishes.
4. `--dry-run --refine` skips publish but keeps issue-refine prefix.
5. Fallback when `gh` fails (default mode).

## Usage

Run via the standard test runner; sources `tests/common.sh` for shared setup.
