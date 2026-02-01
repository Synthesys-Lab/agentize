# test-lol-help-text.sh

Checks that `lol` help output includes the documented commands and flags.

## Coverage

- Usage text lists `lol use-branch` and `lol upgrade`.
- `--keep-branch` appears in the help text.
- `lol plan --help` exposes required planner flags.
