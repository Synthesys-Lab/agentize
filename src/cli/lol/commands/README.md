# lol Command Implementations

## Purpose

Per-command implementation files for the `lol` CLI. Each file exports exactly one `lol_cmd_*` function that implements a specific command.

## File Map

| File | Function | Description |
|------|----------|-------------|
| `init.sh` | `lol_cmd_init` | Initialize new SDK project with templates |
| `update.sh` | `lol_cmd_update` | Update existing project configuration |
| `upgrade.sh` | `lol_cmd_upgrade` | Upgrade agentize installation via git |
| `version.sh` | `lol_cmd_version` | Display version information |
| `project.sh` | `lol_cmd_project` | GitHub Projects v2 integration |
| `serve.sh` | `lol_cmd_serve` | Run polling server for automation |
| `claude-clean.sh` | `lol_cmd_claude_clean` | Remove stale entries from ~/.claude.json |
| `usage.sh` | `lol_cmd_usage` | Report Claude Code token usage statistics |

## Design

- All functions run in subshells to preserve `set -e` semantics
- The parent `commands.sh` sources all files in this directory
- Functions use positional arguments; parsers in `parsers.sh` handle CLI flags
