# test-lol-complete-flags.sh

Validates `lol --complete <topic>` returns the expected flag sets.

## Coverage

- Existing flag topics return the documented flags.
- `upgrade-flags` includes `--keep-branch`.
- Unknown or removed topics return empty output.
