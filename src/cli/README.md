# CLI Source Files

## Purpose

Source files for the `wt` (worktree) command-line interface implementation.

## Contents

### Key Files

- `wt.sh` - Main worktree CLI entry point and command dispatcher
  - Implements `wt` command for managing git worktrees
  - Handles subcommands: `init`, `spawn`, `list`, `remove`, `prune`, `goto`, `help`
  - Provides both executable and sourceable interfaces
  - Integrates with GitHub via `gh` CLI for issue validation

## Usage

The CLI is invoked through the `wt` wrapper function (defined in `setup.sh`):

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

Direct script invocation (for development/testing):

```bash
./src/cli/wt.sh <command> [args]
```

## Implementation Details

The `wt.sh` script serves dual roles:
1. **Executable mode**: Command dispatcher for worktree operations
2. **Sourceable mode**: Exports functions for shell integration (e.g., `wt goto`)

Worktrees are created in the `trees/` directory following the `issue-{N}` branch naming convention.

## Related Documentation

- [tests/cli/](../../tests/cli/) - CLI command tests
- [tests/e2e/](../../tests/e2e/) - End-to-end worktree tests
- [scripts/README.md](../../scripts/README.md) - Scripts directory overview
- [docs/cli/wt.md](../../docs/cli/wt.md) - CLI command documentation (if exists)
