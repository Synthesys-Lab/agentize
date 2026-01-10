# wt CLI Modules

## Purpose

Modular implementation of the `wt` git worktree helper. These files are sourced by `wt.sh` in order to provide the complete `wt` command functionality.

## Module Map

| File | Description | Exports |
|------|-------------|---------|
| `helpers.sh` | Repository detection and path resolution | `wt_common`, `wt_is_bare_repo`, `wt_get_default_branch`, `wt_configure_origin_tracking`, `wt_resolve_worktree`, `wt_claim_issue_status` |
| `completion.sh` | Shell-agnostic completion helper | `wt_complete` |
| `commands.sh` | Command implementations | `cmd_common`, `cmd_init`, `cmd_clone`, `cmd_goto`, `cmd_list`, `cmd_remove`, `cmd_prune`, `cmd_purge`, `cmd_spawn`, `cmd_rebase`, `cmd_help` |
| `dispatch.sh` | Main dispatcher and entry point | `wt` |

## Load Order

The parent `wt.sh` sources modules in this order:

1. `helpers.sh` - No dependencies
2. `completion.sh` - No dependencies
3. `commands.sh` - Depends on helpers
4. `dispatch.sh` - Depends on all above

## Design Principles

- Each module is self-contained with clearly defined exports
- All functions use the `wt_` or `cmd_` prefix to avoid namespace collisions
- Helper functions (`wt_*`) provide reusable utilities for path resolution and repo detection
- Command implementations (`cmd_*`) map directly to subcommands
- The dispatcher handles top-level routing and delegates to command implementations

## Related Documentation

- `../wt.md` - Interface documentation
- `../../docs/cli/wt.md` - User documentation
- `../../docs/feat/cli/wt.md` - Detailed flag reference
