# lol CLI Modules

## Purpose

Modular implementation of the `lol` SDK CLI. These files are sourced by `lol.sh` in order to provide the complete `lol` command functionality.

## Module Map

| File | Description | Exports |
|------|-------------|---------|
| `helpers.sh` | Language detection and utility functions | `lol_detect_lang` |
| `completion.sh` | Shell-agnostic completion helper | `lol_complete` |
| `project-lib.sh` | Shared project setup library | `project_init_context`, `project_preflight_check`, `project_read_metadata`, `project_update_metadata`, `project_create`, `project_associate`, `project_generate_automation`, `project_verify_status_options` |
| `commands.sh` | Thin loader that sources `commands/*.sh` | All `lol_cmd_*` functions |
| `commands/` | Per-command implementation files | See below |
| `dispatch.sh` | Main dispatcher and help text | `lol` |
| `parsers.sh` | Argument parsing for each command | `lol_parse_project`, `lol_parse_serve`, `lol_parse_usage`, `lol_parse_claude_clean` |

### commands/ Directory

| File | Exports |
|------|---------|
| `upgrade.sh` | `lol_cmd_upgrade` |
| `version.sh` | `lol_cmd_version` |
| `project.sh` | `lol_cmd_project` |
| `serve.sh` | `lol_cmd_serve` |
| `claude-clean.sh` | `lol_cmd_claude_clean` |
| `usage.sh` | `lol_cmd_usage` |

## Load Order

The parent `lol.sh` sources modules in this order:

1. `helpers.sh` - No dependencies
2. `completion.sh` - No dependencies
3. `project-lib.sh` - Depends on `scripts/gh-graphql.sh`
4. `commands.sh` - Sources all files from `commands/`, depends on helpers and project-lib
5. `parsers.sh` - Depends on commands
6. `dispatch.sh` - Depends on all above

## Design Principles

- Each module is self-contained and sources only its required dependencies
- All functions use the `lol_` prefix to avoid namespace collisions
- Command implementations (`lol_cmd_*`) run in subshells to preserve `set -e` semantics
- Parsers convert CLI arguments to positional arguments for command functions
- The dispatcher handles top-level routing and help text

## Related Documentation

- `../lol.md` - Interface documentation
- `../../docs/cli/lol.md` - User documentation
