# dispatch.sh

## Purpose

Command dispatcher for `acw`. Owns argument parsing, help text, validation, and
provider invocation flow.

## External Interface

### Command
```bash
acw [--editor] [--stdout] <cli-name> <model-name> [<input-file>] [<output-file>] [options...]
```

**Parameters**:
- `cli-name`: Provider identifier (`claude`, `codex`, `opencode`, `cursor`)
- `model-name`: Model identifier passed to the provider
- `input-file`: Prompt file path (required unless `--editor` is used)
- `output-file`: Response file path (required unless `--stdout` is used)
- `options...`: Provider-specific options passed through unchanged

**Flags**:
- `--editor`: Uses `$EDITOR` to populate a temporary input file. The editor must
  exit with status 0 and the file must contain non-whitespace content.
- `--stdout`: Routes output to `/dev/stdout` and merges provider stderr into
  stdout for the invocation.
- `--complete <topic>`: Prints completion values for the given topic.
- `--help`: Prints usage text.

**Ordering rule**:
- `acw` flags must appear before `cli-name`. Use `--` to pass provider options
  that collide with `acw` flags.

**Exit behavior**:
- Returns the provider exit code on execution.
- Emits argument or validation errors to stderr with non-zero exit codes as
  documented in `acw.md`.

## Internal Helpers

### _acw_usage()
Prints usage text, options, providers, and examples.

### _acw_validate_no_positional_args()
Ensures editor/stdout modes do not accept extra positional arguments. Allows
values following flags and allows positional values after `--`.
