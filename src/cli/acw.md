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
2. `providers.sh` - Provides provider functions (`acw_invoke_claude`, etc.)
3. `completion.sh` - Provides completion helper (`acw_complete`)
4. `dispatch.sh` - Provides main entry point (`acw`)

## Exported Functions

### Main Entry Point

```bash
acw <cli-name> <model-name> <input-file> <output-file> [options...]
```

Validates arguments, dispatches to provider function, returns provider exit code.

### Provider Functions

```bash
acw_invoke_claude <model> <input> <output> [options...]
acw_invoke_codex <model> <input> <output> [options...]
acw_invoke_opencode <model> <input> <output> [options...]
acw_invoke_cursor <model> <input> <output> [options...]
```

Each provider function handles CLI-specific invocation patterns.

### Completion Function

```bash
acw_complete <topic>
# Returns: newline-separated list of completions for the topic
# Topics: providers, cli-options
```

### Private Helper Functions

Helper functions are prefixed with `_acw_` to prevent tab-completion pollution:

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
- Handle CLI-specific flag formats
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
