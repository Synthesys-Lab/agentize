# completion.sh

Shell completion helper for `acw`. Provides newline-delimited tokens for provider names and common CLI options.

## External Interface

### acw --complete <topic>

Returns completion candidates for the given topic without requiring provider configuration.

**Parameters**:
- `topic`: Completion category (`providers` or `cli-options`).

**Output**:
- Newline-delimited tokens to stdout.

## Internal Helpers

### _acw_complete()

Maps completion topics to stable lists:
- `providers`: `claude`, `codex`, `opencode`, `cursor`.
- `cli-options`: `--help`, `--model`, `--max-tokens`, `--yolo`, `--silent`.

Returns an empty list for unknown topics to keep completion behavior resilient.
