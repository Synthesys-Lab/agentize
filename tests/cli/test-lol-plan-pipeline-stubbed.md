# tests/cli/test-lol-plan-pipeline-stubbed.sh

## Purpose

Validate `lol plan` pipeline behavior via the Python backend with stubbed `acw` and consensus scripts.

## Stubs

- `acw` loader (`PLANNER_ACW_SCRIPT`): Writes deterministic stage outputs and logs invocations.
- `external-consensus.sh` (`_PLANNER_CONSENSUS_SCRIPT`): Produces a predictable consensus file.

## Test Cases

1. `--dry-run` mode uses timestamp artifacts, writes `.txt` stage outputs, and skips issue creation.
2. `--verbose` mode emits stage progress labels and timing logs.

## Usage

Run via the standard test runner; sources `tests/common.sh` for shared setup.
