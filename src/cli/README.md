# CLI Source Files

## Purpose

Source-first libraries for Agentize CLI commands. These files are the canonical implementations sourced by `setup.sh` to provide shell functions.

## Contents

### Key Files

- `wt.sh` - Worktree CLI library (canonical source)
  - Implements `wt` command for managing git worktrees
  - Handles subcommands: `init`, `spawn`, `list`, `remove`, `prune`, `goto`, `help`
  - Provides both executable and sourceable interfaces
  - Integrates with GitHub via `gh` CLI for issue validation
  - Interface documentation: `wt.md`

- `lol.sh` - SDK CLI library (canonical source)
  - Implements `lol` command for SDK initialization and management
  - Handles subcommands: `init`, `update`, `upgrade`, `project`, `version`
  - Command implementations run in subshell functions to preserve `set -e` semantics
  - Interface documentation: `lol.md`

## Usage

### Worktree CLI (`wt`)

```bash
# Initialize worktree environment
wt init

# Create worktree for GitHub issue #42
wt spawn 42

# List all worktrees
wt list

# Switch to worktree (when sourced)
wt goto 42

# Remove worktree
wt remove 42
```

### SDK CLI (`lol`)

```bash
# Initialize new project
lol init --name my-project --lang python --path /path/to/project

# Update existing project
lol update

# Upgrade agentize installation
lol upgrade

# Display version
lol --version

# GitHub Projects integration
lol project --create --org MyOrg --title "My Project"
```

### Direct Script Invocation

For development and testing:

```bash
./src/cli/wt.sh <command> [args]
./src/cli/lol.sh <command> [args]
```

## Implementation Details

Both `wt.sh` and `lol.sh` serve dual roles:
1. **Sourceable mode**: Primary usage via `setup.sh` - exports functions for shell integration
2. **Executable mode**: Direct script execution for testing and non-interactive use

### Source-first Pattern

The source-first pattern ensures:
- Single source of truth for CLI logic in `src/cli/`
- Wrapper scripts in `scripts/` delegate to library functions
- `setup.sh` sources these libraries for interactive shell use

### Command Isolation

`lol.sh` command implementations (`lol_cmd_*`) use subshell functions to:
- Preserve `set -e` error handling semantics
- Isolate environment variables from the user's shell
- Match the behavior of the original executable scripts

## Related Documentation

- [tests/cli/](../../tests/cli/) - CLI command tests
- [tests/e2e/](../../tests/e2e/) - End-to-end integration tests
- [scripts/README.md](../../scripts/README.md) - Wrapper scripts overview
- [docs/cli/wt.md](../../docs/cli/wt.md) - `wt` command user documentation
- [docs/cli/lol.md](../../docs/cli/lol.md) - `lol` command user documentation
