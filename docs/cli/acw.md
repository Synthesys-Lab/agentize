# acw - Agent CLI Wrapper

Unified file-based interface for invoking multiple AI CLI tools.

## Synopsis

```bash
acw <cli-name> <model-name> <input-file> <output-file> [cli-options...]
acw --complete <topic>
acw --help
```

## Description

`acw` provides a consistent interface for invoking different AI CLI tools (claude, codex, opencode, cursor/agent) with file-based input/output. This enables scripts to use a uniform interface regardless of the underlying AI provider.

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `cli-name` | Yes | Provider name: `claude`, `codex`, `opencode`, `cursor` |
| `model-name` | Yes | Model identifier passed to the provider |
| `input-file` | Yes | Path to file containing the prompt |
| `output-file` | Yes | Path where response will be written |
| `cli-options` | No | Additional options passed to the provider CLI |

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
| 127 | Provider execution failed |

## Examples

### Basic Usage

```bash
# Invoke Claude with a prompt file
acw claude claude-sonnet-4-20250514 prompt.txt response.txt

# Invoke Codex
acw codex gpt-4o prompt.txt response.txt

# Pass additional options to the provider
acw claude claude-sonnet-4-20250514 prompt.txt response.txt --max-tokens 4096
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

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AGENTIZE_HOME` | Required. Path to agentize installation. |

## Shell Completion

`acw` supports shell autocompletion for zsh. The completion is provided by `src/completion/_acw`.

### Completion Topics

Use `acw --complete <topic>` to get completion values programmatically:

| Topic | Description |
|-------|-------------|
| `providers` | List of supported providers (claude, codex, opencode, cursor) |
| `cli-options` | Common CLI options (e.g., --help, --model, --max-tokens, --yolo) |

### Setup

For zsh, add the completion directory to your `fpath`:

```bash
fpath=($AGENTIZE_HOME/src/completion $fpath)
autoload -Uz compinit && compinit
```

## Notes

- The output directory is created automatically if it doesn't exist
- Provider-specific options are passed through unchanged, except `--yolo` is normalized to Claude's `--dangerously-skip-permissions`
- The wrapper returns the provider's exit code on successful execution
- Best-effort providers (opencode, cursor) may have limited functionality
- Only `acw` is the public function; all helper functions (provider invocation, completion, validation) are internal (prefixed with `_acw_`) and won't appear in tab completion

## See Also

- `src/cli/acw.md` - Interface documentation
- `src/cli/acw/README.md` - Module architecture
