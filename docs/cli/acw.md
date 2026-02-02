# acw - Agent CLI Wrapper

Unified file-based interface for invoking multiple AI CLI tools.

## Synopsis

```bash
acw [--chat [session-id]] [--editor] [--stdout] <cli-name> <model-name> [<input-file>] [<output-file>] [cli-options...]
acw --chat-list
acw --complete <topic>
acw --help
```

## Description

`acw` provides a consistent interface for invoking different AI CLI tools (claude, codex, opencode, cursor/agent) with file-based input/output. Optional flags allow editor-based input and stdout output while preserving the default file-based workflow.

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `cli-name` | Yes | Provider name: `claude`, `codex`, `opencode`, `cursor` |
| `model-name` | Yes | Model identifier passed to the provider |
| `input-file` | Conditional | Path to file containing the prompt (required unless `--editor` is used) |
| `output-file` | Conditional | Path where response will be written (required unless `--stdout` is used) |
| `cli-options` | No | Additional options passed to the provider CLI |

## Options

| Option | Description |
|--------|-------------|
| `--chat [session-id]` | Start or continue a chat session. Creates new session if no ID provided. |
| `--chat-list` | List available chat sessions and exit. |
| `--editor` | Use `$EDITOR` to create the input content (mutually exclusive with `input-file`) |
| `--stdout` | Write output to stdout (mutually exclusive with `output-file`). When not combined with `--chat`, merges provider stderr into stdout. When combined with `--chat`, provider stderr is written to `<session-id>.stderr` sidecar file. |
| `--complete <topic>` | Print completion values for the given topic |
| `--help` | Show help text |

## Supported Providers

| Provider | CLI Binary | Status |
|----------|------------|--------|
| `claude` | `claude` | Full support |
| `codex` | `codex` | Full support |
| `opencode` | `opencode` | Best-effort |
| `cursor` | `agent` | Best-effort |

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Missing required arguments |
| 2 | Unknown provider |
| 3 | Input file not found or not readable |
| 4 | Provider CLI binary not found |
| 5 | Chat session error (invalid ID, missing file, or format error) |
| 127 | Provider execution failed |

## Examples

### Basic Usage

```bash
# Invoke Claude with a prompt file
acw claude claude-sonnet-4-20250514 prompt.txt response.txt
# Provider stderr is written to response.txt.stderr in file mode

# Invoke Codex
acw codex gpt-4o prompt.txt response.txt

# Pass additional options to the provider
acw claude claude-sonnet-4-20250514 prompt.txt response.txt --max-tokens 4096

# Compose a prompt in your editor
acw --editor claude claude-sonnet-4-20250514 response.txt

# Stream output to stdout (merged with provider stderr)
acw --stdout claude claude-sonnet-4-20250514 prompt.txt

# Start a new chat session (prints session ID)
acw --chat claude claude-sonnet-4-20250514 prompt.txt response.txt

# Continue an existing chat session
acw --chat abc12345 claude claude-sonnet-4-20250514 prompt.txt response.txt

# List all chat sessions
acw --chat-list
```

### Script Integration

```bash
#!/usr/bin/env bash
source "$AGENTIZE_HOME/src/cli/acw.sh"

# Use acw in your script
acw claude claude-sonnet-4-20250514 /tmp/prompt.txt /tmp/response.txt
if [ $? -eq 0 ]; then
    echo "Response written to /tmp/response.txt"
fi
```

## Chat Sessions

Chat sessions enable multi-turn conversations by persisting history as markdown files.

### Session Storage

Sessions are stored under `$AGENTIZE_HOME/.tmp/acw-sessions/` as markdown files with YAML front matter:

```markdown
---
provider: claude
model: claude-sonnet-4-20250514
created: 2025-01-15T10:30:00Z
---

# User
What is the capital of France?

# Assistant
The capital of France is Paris.
```

### Session IDs

- Format: 8-character base62 string (a-z, A-Z, 0-9)
- Generated automatically when `--chat` is used without an ID
- Printed to stderr when a new session is created

### Chat Flow

1. **New session**: `acw --chat` creates a session file, prints its ID, and runs the first turn.
2. **Continue session**: `acw --chat <id>` prepends the session history to the current input and appends the new turn after the provider responds.
3. **List sessions**: `acw --chat-list` lists session IDs with provider, model, and creation date.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AGENTIZE_HOME` | Required. Path to agentize installation. |
| `EDITOR` | Required when using `--editor`. Command used to compose the prompt. |

## Shell Completion

`acw` supports shell autocompletion for zsh. The completion is provided by `src/completion/_acw`.

### Completion Topics

Use `acw --complete <topic>` to get completion values programmatically:

| Topic | Description |
|-------|-------------|
| `providers` | List of supported providers (claude, codex, opencode, cursor) |
| `cli-options` | Common CLI options (e.g., --help, --editor, --stdout, --model, --max-tokens, --yolo) |

### Setup

For zsh, add the completion directory to your `fpath`:

```bash
fpath=($AGENTIZE_HOME/src/completion $fpath)
autoload -Uz compinit && compinit
```

## Notes

- The output directory is created automatically if it doesn't exist (skipped when `--stdout` is used)
- Provider-specific options are passed through unchanged, except `--yolo` is normalized to Claude's `--dangerously-skip-permissions`
- The wrapper returns the provider's exit code on successful execution
- Best-effort providers (opencode, cursor) may have limited functionality
- Only `acw` is the public function; all helper functions (provider invocation, completion, validation) are internal (prefixed with `_acw_`) and won't appear in tab completion
- `acw` flags must appear before `cli-name`. Use `--` to pass provider options that collide with `acw` flags.
- `--stdout` behavior:
  - Without `--chat`: merges provider stderr into stdout so progress and output can be piped together.
  - With `--chat`: provider stderr is appended to `.tmp/acw-sessions/<session-id>.stderr` to keep stdout clean for piping. Empty sidecar files created by `acw` are automatically removed.
- In file mode (no `--stdout`), provider stderr is written to `<output-file>.stderr`. Empty sidecar files are removed after the provider exits.

## See Also

- `src/cli/acw.md` - Interface documentation
- `src/cli/acw/README.md` - Module architecture
