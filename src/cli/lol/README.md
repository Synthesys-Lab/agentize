# lol CLI Modules

## Purpose

Modular implementation of the `lol` SDK CLI. These files are sourced by `lol.sh` in order to provide the complete `lol` command functionality.

## Module Map

| File | Description | Exports |
|------|-------------|---------|
| `helpers.sh` | Language detection and utility functions | `lol_detect_lang` |
| `completion.sh` | Shell-agnostic completion helper | `lol_complete` |
| `commands.sh` | Thin loader that sources `commands/*.sh` | All `lol_cmd_*` functions |
| `commands/` | Per-command implementation files | See below |
| `dispatch.sh` | Main dispatcher and help text | `lol` |
| `parsers.sh` | Argument parsing for each command | `lol_parse_init`, `lol_parse_update`, `lol_parse_apply`, `lol_parse_project`, `lol_parse_serve` |

### commands/ Directory

| File | Exports |
|------|---------|
| `init.sh` | `lol_cmd_init` |
| `update.sh` | `lol_cmd_update` |
| `upgrade.sh` | `lol_cmd_upgrade` |
| `version.sh` | `lol_cmd_version` |
| `project.sh` | `lol_cmd_project` |
| `serve.sh` | `lol_cmd_serve` |
| `claude-clean.sh` | `lol_cmd_claude_clean` |

## Load Order

The parent `lol.sh` sources modules in this order:

1. `helpers.sh` - No dependencies
2. `completion.sh` - No dependencies
3. `commands.sh` - Sources all files from `commands/`, depends on helpers
4. `parsers.sh` - Depends on commands
5. `dispatch.sh` - Depends on all above

## Design Principles

- Each module is self-contained and sources only its required dependencies
- All functions use the `lol_` prefix to avoid namespace collisions
- Command implementations (`lol_cmd_*`) run in subshells to preserve `set -e` semantics
- Parsers convert CLI arguments to positional arguments for command functions
- The dispatcher handles top-level routing and help text

## Related Documentation

- `../lol.md` - Interface documentation
- `../../docs/cli/lol.md` - User documentation
- `../../docs/feat/cli/lol.md` - Detailed flag reference
