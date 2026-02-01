# lol CLI Modules

## Purpose

Modular implementation of the `lol` SDK CLI. These files are sourced by `lol.sh` in order to provide the complete `lol` command functionality.

## Module Map

| File | Description | Exports |
|------|-------------|---------|
| `helpers.sh` | Language detection and utility functions | `_lol_detect_lang` (private) |
| `completion.sh` | Shell-agnostic completion helper | `_lol_complete` (private) |
| `project-lib.sh` | Shared project setup library | `project_init_context`, `project_preflight_check`, `project_read_metadata`, `project_update_metadata`, `project_create`, `project_associate`, `project_generate_automation`, `project_verify_status_options` |
| `commands.sh` | Thin loader that sources `commands/*.sh` | All `_lol_cmd_*` functions (private) |
| `commands/` | Per-command implementation files | See below |
| `dispatch.sh` | Main dispatcher and help text | `lol` |
| `parsers.sh` | Argument parsing for each command | `_lol_parse_project`, `_lol_parse_serve`, `_lol_parse_usage`, `_lol_parse_claude_clean`, `_lol_parse_plan`, `_lol_parse_impl`, `_lol_parse_use_branch`, `_lol_parse_upgrade` |

### commands/ Directory

| File | Exports |
|------|---------|
| `upgrade.sh` | `_lol_cmd_upgrade` |
| `use-branch.sh` | `_lol_cmd_use_branch` |
| `version.sh` | `_lol_cmd_version` |
| `project.sh` | `_lol_cmd_project` |
| `serve.sh` | `_lol_cmd_serve` |
| `claude-clean.sh` | `_lol_cmd_claude_clean` |
| `usage.sh` | `_lol_cmd_usage` |
| `plan.sh` | `_lol_cmd_plan` |
| `impl.sh` | `_lol_cmd_impl` |

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
- `lol()` is the only public entrypoint; internal helpers use the `_lol_` prefix
- Command implementations (`_lol_cmd_*`) run in subshells to preserve `set -e` semantics
- Parsers convert CLI arguments to positional arguments for command functions
- The dispatcher handles top-level routing and help text

## Related Documentation

- `../lol.md` - Interface documentation
- `../../docs/cli/lol.md` - User documentation
