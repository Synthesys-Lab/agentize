# test-lol-complete-commands.sh

Verifies `lol --complete commands` returns the documented subcommand list.

## Coverage

- Core command names appear in newline-delimited output.
- `use-branch` is included in the completion list.
- Removed commands are excluded.
