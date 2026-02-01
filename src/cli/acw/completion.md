# completion.sh

## Purpose

Completion helper for `acw` that returns newline-delimited lists for shell
completion systems.

## External Interface

### _acw_complete <topic>

**Topics**:
- `providers`: Lists supported providers (`claude`, `codex`, `opencode`, `cursor`).
- `cli-options`: Lists common CLI options (`--help`, `--editor`, `--stdout`,
  `--model`, `--max-tokens`, `--yolo`).

**Output**:
- Prints one value per line to stdout.
- Returns empty output for unknown topics.

## Internal Helpers

None.
