# dispatch.sh

## Purpose

Dispatcher for `acw` that owns help text, argument validation flow, and provider invocation.

## External Interface

### `acw`

```bash
acw <cli-name> <model-name> <input-file> <output-file> [options...]
acw --complete <topic>
acw --help
```

**Parameters**:
- `cli-name`: Provider name (`claude`, `codex`, `opencode`, `cursor`)
- `model-name`: Provider model identifier
- `input-file`: Prompt file path
- `output-file`: Response file path
- `options`: Additional provider options; `--silent` is reserved for acw

**Options**:
- `--help`: Print usage text
- `--complete <topic>`: Emit completion values for a topic
- `--silent`: Suppress provider stderr output while keeping acw validation errors visible

**Exit codes**: See `docs/cli/acw.md` for the authoritative list.

### `_acw_usage`

Prints the usage text for `acw` to stdout. Called for `--help` and missing-argument flows.

## Internal Flow

- `--help` and `--complete` are handled before argument validation.
- Required arguments are validated and provider name is checked.
- Reserved options (currently `--silent`) are stripped from provider arguments.
- When `--silent` is set, provider stderr is redirected to `/dev/null` only for the provider invocation.
- The provider exit code is returned unchanged.
