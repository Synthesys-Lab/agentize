# lol CLI Modules

## Purpose

Modular implementation of the `lol` SDK CLI. These files are sourced by `lol.sh` in order to provide the complete `lol` command functionality.

## Module Map

| File | Description | Exports |
|------|-------------|---------|
| `helpers.sh` | Language detection and utility functions | `lol_detect_lang` |
| `completion.sh` | Shell-agnostic completion helper | `lol_complete` |
| `commands.sh` | Command implementations | `lol_cmd_init`, `lol_cmd_update`, `lol_cmd_upgrade`, `lol_cmd_project`, `lol_cmd_serve`, `lol_cmd_version` |
| `dispatch.sh` | Main dispatcher and help text | `lol` |
| `parsers.sh` | Argument parsing for each command | `lol_parse_init`, `lol_parse_update`, `lol_parse_apply`, `lol_parse_project`, `lol_parse_serve` |

## Load Order

The parent `lol.sh` sources modules in this order:

1. `helpers.sh` - No dependencies
2. `completion.sh` - No dependencies
3. `commands.sh` - Depends on helpers
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
