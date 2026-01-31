# tests/cli/test-lol-plan-pipeline-stubbed.sh

## Purpose

Validate `lol plan` pipeline behavior with a stubbed `acw` response and consensus script.

## Stubs

- `acw`: Deterministic pipeline output for assertions (responds based on input content)
- `external-consensus.sh`: Stub consensus script that produces predictable output

## Test Cases

1. `--dry-run` mode uses timestamp artifacts and skips issue creation
2. `--verbose` mode outputs detailed stage info

## Usage

Run via the standard test runner; sources `tests/common.sh` for shared setup.
