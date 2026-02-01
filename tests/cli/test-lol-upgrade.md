# test-lol-upgrade.sh

Validates `lol upgrade` behavior for branch selection and setup workflow.

## Coverage

- Default behavior switches to the default branch before pulling updates.
- `--keep-branch` keeps the current branch and pulls its upstream.
- `make setup` runs after successful pulls and emits reload instructions.
- Optional Claude plugin refresh is invoked when the CLI is available.
