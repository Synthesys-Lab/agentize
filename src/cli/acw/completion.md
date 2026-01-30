# completion.sh

## Purpose

Provide newline-delimited completion values for `acw` topics.

## External Interface

### `_acw_complete`

```bash
_acw_complete <topic>
```

**Topics**:
- `providers`: Supported provider names
- `cli-options`: Common CLI options recognized by acw or popular providers

**Output**: Newline-delimited list of completion values for the requested topic.

## Topic Details

### `providers`

Returns:
- `claude`
- `codex`
- `opencode`
- `cursor`

### `cli-options`

Returns:
- `--help`
- `--model`
- `--max-tokens`
- `--yolo`
- `--silent`

## Behavior Notes

Unknown topics return an empty result to keep completion resilient.
