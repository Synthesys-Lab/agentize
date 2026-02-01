# completion.sh

Shell completion helper for the `lol` CLI. This module provides structured lists of
subcommands and flags for completion systems.

## External Interface

### lol --complete <topic>

Returns newline-delimited completion candidates for the given topic. The `lol`
entrypoint routes `--complete` to the internal helper without requiring a full
agentize environment.

**Parameters**:
- `topic`: Completion category (e.g., `commands`, `project-modes`, `plan-flags`,
  `upgrade-flags`).

**Output**:
- Newline-delimited tokens to stdout.

## Internal Helpers

### _lol_complete()

Private helper that maps topic names to completion lists for `lol` subcommands
and flags. Returns an empty list for unknown topics to keep completion behavior
stable across shells.
