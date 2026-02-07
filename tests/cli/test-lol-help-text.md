# test-lol-help-text.sh

Checks that `lol` help output includes the documented commands and flags.

## Coverage

- Usage text lists `lol use-branch` and `lol upgrade`.
- Usage text lists `lol simp`.
- `--keep-branch` appears in the help text.
- `--wait-for-ci` appears in the help text.
- `lol plan --help` exposes required planner flags.
