# dispatch.sh

## Purpose

Command dispatcher for `acw`. Owns argument parsing, help text, validation, and
provider invocation flow including chat session orchestration.

## External Interface

### Command
```bash
acw [--chat [session-id]] [--editor] [--stdout] <cli-name> <model-name> [<input-file>] [<output-file>] [options...]
acw --chat-list
```

**Parameters**:
- `cli-name`: Provider identifier (`claude`, `codex`, `opencode`, `cursor`)
- `model-name`: Model identifier passed to the provider
- `input-file`: Prompt file path (required unless `--editor` is used)
- `output-file`: Response file path (required unless `--stdout` is used)
- `options...`: Provider-specific options passed through unchanged

**Flags**:
- `--chat [session-id]`: Enables chat mode. If `session-id` is omitted, creates a
  new session; if provided, continues that session.
- `--chat-list`: Lists available session IDs and basic metadata, then exits.
- `--editor`: Uses `$EDITOR` to populate a temporary input file. The editor must
  exit with status 0 and the file must contain non-whitespace content.
- `--stdout`: Routes output to `/dev/stdout` and merges provider stderr into
  stdout for the invocation.
- File mode (no `--stdout`) redirects provider stderr to `<output-file>.stderr`
  and removes the sidecar file when stderr is empty.
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

## Chat Mode

In chat mode, the dispatcher orchestrates session creation, history prepending,
and turn appending:

1. **New session**: Creates a session file with YAML front matter, prepends an
   empty history, runs the provider, and appends the first turn.
2. **Continue session**: Validates the session file, prepends existing history
   to a combined temp file, runs the provider, and appends the new turn.

**Stdout capture**: When `--stdout` is combined with `--chat`, the provider
output is captured to a temp file. After the provider exits, the captured
content is emitted to stdout and the assistant response is appended to the
session file.

**Stderr sidecar**: When `--stdout` is combined with `--chat`, provider stderr
is appended to `<session-id>.stderr` beside the session file rather than
merged into stdout. This keeps stdout clean for piping. If the sidecar file
is newly created and remains empty after the provider exits, it is removed.
