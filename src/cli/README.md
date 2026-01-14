# CLI Source Files

## Purpose

Source-first libraries for Agentize CLI commands. These files are the canonical implementations sourced by `setup.sh` to provide shell functions.

## Contents

### Key Files

- `wt.sh` - Worktree CLI library (canonical source, thin loader)
  - Sources modular files from `wt/` directory
  - Exports `wt` command for managing git worktrees
  - Handles subcommands: `clone`, `common`, `init`, `goto`, `spawn`, `list`, `remove`, `prune`, `purge`, `pathto`, `rebase`, `help`
  - Interface documentation: `wt.md`

- `wt/` - Worktree CLI modular implementation
  - `helpers.sh` - Repository detection, path resolution, and project status helpers
  - `completion.sh` - Shell-agnostic completion helper
  - `commands.sh` - Command implementations (cmd_*)
  - `dispatch.sh` - Main dispatcher and entry point
  - See `wt/README.md` for module map and load order

- `lol.sh` - SDK CLI library (canonical source, thin loader)
  - Sources modular files from `lol/` directory
  - Exports `lol` command for SDK management
  - Handles subcommands: `upgrade`, `project`, `serve`, `usage`, `claude-clean`, `version`
  - Interface documentation: `lol.md`

- `lol/` - SDK CLI modular implementation
  - `helpers.sh` - Language detection and utility functions
  - `completion.sh` - Shell-agnostic completion helper
  - `commands.sh` - Thin loader that sources `commands/*.sh`
  - `commands/` - Per-command implementations (upgrade.sh, project.sh, etc.)
  - `dispatch.sh` - Main dispatcher, help text, and entry point
  - `parsers.sh` - Argument parsing for each command
  - See `lol/README.md` for module map and load order

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
# Upgrade agentize installation
lol upgrade

# Display version
lol --version

# GitHub Projects integration
lol project --create --org MyOrg --title "My Project"

# Report token usage
lol usage --today

# Clean stale project entries
lol claude-clean
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
