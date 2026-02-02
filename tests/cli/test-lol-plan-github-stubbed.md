# tests/cli/test-lol-plan-github-stubbed.sh

## Purpose

Validate GitHub issue creation and publish behavior for `lol plan` with a stubbed `gh` CLI.

## Stubs

- `gh` CLI: Records `issue create` and `issue edit` calls while returning deterministic URLs.
- `acw` loader (`PLANNER_ACW_SCRIPT`): Writes minimal stage outputs.
- `external-consensus.sh` (`_PLANNER_CONSENSUS_SCRIPT`): Writes a consensus plan containing an `Implementation Plan` header for title extraction.

## Test Cases

1. Placeholder issue title includes the truncated feature description.
2. Issue publish updates the title with `[plan] [#N]` prefix and adds the `agentize:plan` label.
3. The final consensus path is printed for local inspection.

## Usage

Run via the standard test runner; sources `tests/common.sh` for shared setup.
