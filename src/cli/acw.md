# acw.sh Interface Documentation

## Purpose

Thin loader for the Agent CLI Wrapper module, providing a unified file-based interface to invoke multiple AI CLI tools.

## Module Structure

```
acw.sh          # Entry point (this file) - thin loader
acw/
  helpers.sh    # Validation and utility functions (private)
  providers.sh  # Provider-specific invocation functions
  completion.sh # Completion helper for shell integration
  dispatch.sh   # Main dispatcher, help text, argument parsing
  README.md     # Module map and architecture
```

## Load Order

1. `helpers.sh` - Provides validation helpers (`_acw_validate_args`, `_acw_check_cli`, etc.)
2. `providers.sh` - Provides provider functions (`_acw_invoke_claude`, etc.)
3. `completion.sh` - Provides completion helper (`_acw_complete`)
4. `dispatch.sh` - Provides main entry point (`acw`)

## Exported Functions

### Public Entry Point

```bash
acw [--editor] [--stdout] <cli-name> <model-name> [<input-file>] [<output-file>] [options...]
```

Validates arguments, dispatches to provider function, returns provider exit code.

**Flag behavior:**
- `--editor` uses `$EDITOR` to create the input content (mutually exclusive with `input-file`)
- `--stdout` writes output to stdout and merges provider stderr into stdout (mutually exclusive with `output-file`)
- `acw` flags must appear before `cli-name`; use `--` to pass provider options that collide with `acw` flags

This is the **only public function** exported by `acw.sh`. All other functions are internal (prefixed with `_acw_`).

### Private Functions

All helper functions are prefixed with `_acw_` to prevent tab-completion pollution and indicate internal use:

**Provider functions:**
- `_acw_invoke_claude` - Invokes Claude CLI
- `_acw_invoke_codex` - Invokes Codex CLI
- `_acw_invoke_opencode` - Invokes Opencode CLI
- `_acw_invoke_cursor` - Invokes Cursor/Agent CLI

**Completion function:**
- `_acw_complete` - Returns completion values for shell integration

**Validation helpers:**
- `_acw_validate_args` - Validates required arguments
- `_acw_check_cli` - Checks if provider CLI binary exists
- `_acw_ensure_output_dir` - Creates output directory if needed
- `_acw_check_input_file` - Verifies input file exists and is readable

These are internal functions not intended for direct use.

## Design Rationale

### File-Based Interface

Using files for input/output rather than stdin/stdout provides:
- Deterministic content (no buffering issues)
- Easy inspection during debugging
- Compatibility with all provider CLIs
- Natural integration with scripts that generate prompts to files

### Provider Isolation

Each provider has its own invocation function to:
- Handle CLI-specific flag formats (e.g., normalize `--yolo` to Claude's `--dangerously-skip-permissions`)
- Manage output redirection differences
- Allow targeted updates when provider CLIs change

### Bash 3.2 Compatibility

The implementation avoids:
- Associative arrays (bash 4.0+)
- `declare -A` statements
- `${!arr[@]}` indirect expansion

Instead uses:
- Case statements for dispatch
- Positional arguments
- POSIX-compatible constructs

## Usage

### As Sourced Library

```bash
source "$AGENTIZE_HOME/src/cli/acw.sh"
acw claude claude-sonnet-4-20250514 /tmp/in.txt /tmp/out.txt
```

### Direct Execution (Testing)

```bash
./src/cli/acw.sh claude claude-sonnet-4-20250514 /tmp/in.txt /tmp/out.txt
```

## Related

- `docs/cli/acw.md` - User documentation
- `tests/cli/test-acw-*.sh` - Test cases
