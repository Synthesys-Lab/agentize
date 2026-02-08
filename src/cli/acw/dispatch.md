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
- `cli-name`: Provider identifier (`claude`, `codex`, `opencode`, `cursor`, `kimi`)
- `model-name`: Model identifier passed to the provider (Kimi ignores this and
  uses its default model)
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

## Kimi Output Normalization

Kimi outputs stream-json format which requires stripping to extract plain text.
Gemini outputs plain text by default and does not require normalization.

### Kimi Format
Kimi outputs JSON with `content` as a list of typed objects:
```json
{"role":"assistant","content":[{"type":"text","text":"Hello"}]}
```

The dispatcher extracts `content[].type == "text"` segments from assistant messages.

### Normalization Flow
1. Capture raw Kimi output to a temp file.
2. Attempt to parse the full payload as JSON.
3. If that fails, parse each line as NDJSON.
4. Concatenate all `text` fragments in order.
5. If nothing parses, fall back to the raw payload.
6. Write clean assistant text to the final output.

In non-chat `--stdout` mode, stderr is merged into the stream before stripping,
so non-JSON stderr lines may be dropped when Kimi output is normalized.

## Internal Helpers

### _acw_usage()
Prints usage text, options, providers, and examples. Emits the version banner
to stderr via `_acw_log_version()` so help output always includes the current
agentize version context.

### _acw_log_version()

Writes the version banner to stderr in the format
`[agentize] <branch> @<short-hash>`. The branch and short hash are resolved from
`AGENTIZE_HOME` (or the current directory when unset) and fall back to `unknown`
when git metadata is unavailable.

### _acw_validate_no_positional_args()
Ensures editor/stdout modes do not accept extra positional arguments. Allows
values following flags and allows positional values after `--`.

### _acw_kimi_strip_output()
Strips Kimi stream-json output into plain assistant text. Uses Python to parse
either a full JSON payload or NDJSON and falls back to raw output when parsing
fails or yields no text segments.

Filtering rules:
- Only extracts text from `role=assistant` messages
- Skips `role=tool` messages (skill/tool execution results)
- Only processes `type=text` content parts (skips thinking, images, etc.)
- Removes `<system>...</system>` tags from text content

Note: Gemini outputs plain text by default and does not require stripping.

## Chat Mode

In chat mode, the dispatcher orchestrates session creation, history prepending,
and turn appending:

1. **New session**: Creates a session file with YAML front matter (Kimi stores
   `model: default`), prepends an empty history, runs the provider, and appends
   the first turn.
2. **Continue session**: Validates the session file, prepends existing history
   to a combined temp file, runs the provider, and appends the new turn.

**Stdout capture**: When `--stdout` is combined with `--chat`, the provider
output is captured to a temp file. After the provider exits, the captured
content is emitted to stdout and the assistant response is appended to the
session file. If `--editor` is used and stdout is a TTY, the editor prompt
is echoed to stdout before provider invocation, followed by a `Response:`
header so it appears before assistant output.

**Stderr sidecar**: When `--stdout` is combined with `--chat`, provider stderr
is appended to `<session-id>.stderr` beside the session file rather than
merged into stdout. This keeps stdout clean for piping. If the sidecar file
is newly created and remains empty after the provider exits, it is removed.
