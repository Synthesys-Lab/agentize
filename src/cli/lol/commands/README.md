# lol Command Implementations

## Purpose

Per-command implementation files for the `lol` CLI. Each file exports exactly one private `_lol_cmd_*` function that implements a specific command.

## File Map

| File | Function | Description |
|------|----------|-------------|
| `upgrade.sh` | `_lol_cmd_upgrade` | Upgrade agentize installation via git |
| `use-branch.sh` | `_lol_cmd_use_branch` | Switch to a remote development branch |
| `version.sh` | `_lol_cmd_version` | Display version information |
| `project.sh` | `_lol_cmd_project` | GitHub Projects v2 integration |
| `serve.sh` | `_lol_cmd_serve` | Run polling server for automation |
| `claude-clean.sh` | `_lol_cmd_claude_clean` | Remove stale entries from ~/.claude.json |
| `usage.sh` | `_lol_cmd_usage` | Report Claude Code token usage statistics |
| `plan.sh` | `_lol_cmd_plan` | Run multi-agent debate pipeline |
| `impl.sh` | `_lol_cmd_impl` | Automate issue-to-implementation loop |

## Design

- All functions run in subshells to preserve `set -e` semantics
- The parent `commands.sh` sources all files in this directory
- Functions use positional arguments; parsers in `parsers.sh` handle CLI flags
