# Installing Agentize as a Claude Code Plugin

Agentize can be installed as a Claude Code plugin, which provides all commands, skills, agents, and hooks without requiring a git clone into each project.

## Installation Methods

### Method 1: Development Testing (Local Path)

For testing or development, point Claude Code directly to the plugin directory:

```bash
claude --plugin-dir /path/to/agentize
```

### Method 2: From GitHub (Marketplace)

Once published to a marketplace:

```bash
# Add the marketplace (if not already added)
/plugin marketplace add synthesys-lab

# Install the plugin
/plugin install agentize@synthesys-lab
```

## Plugin Structure

When installed as a plugin, Agentize provides:

| Component | Description |
|-----------|-------------|
| **Commands** | `/agentize:ultra-planner`, `/agentize:issue-to-impl`, etc. |
| **Skills** | Planning, review, and documentation skills |
| **Agents** | Code quality reviewer, bold proposer, etc. |
| **Hooks** | Permission management, session tracking |

Note: All commands are namespaced with `agentize:` prefix when used as a plugin.

## Environment Variables

The plugin respects these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `HANDSOFF_MODE` | Enable autonomous continuation | `0` (disabled) |
| `HANDSOFF_MAX_CONTINUATIONS` | Max auto-continuations | `10` |
| `HANDSOFF_DEBUG` | Enable debug logging | `0` (disabled) |
| `AGENTIZE_HOME` | Base directory for session state | `.` (current dir) |

## Dual-Mode Support

Agentize supports both plugin mode and project-local mode:

- **Plugin mode**: `${CLAUDE_PLUGIN_ROOT}` points to the installed plugin directory
- **Project-local mode**: Components are loaded from the project's `.claude/` directory

The hooks automatically detect which mode is active and adjust paths accordingly.

## Differences from Project-Local Installation

| Feature | Project-Local | Plugin |
|---------|---------------|--------|
| Installation | Clone repo, use `.claude/` directory | Install via marketplace or `--plugin-dir` |
| Command prefix | `/ultra-planner` | `/agentize:ultra-planner` |
| Updates | `git pull` | Re-install from marketplace |
| Customization | Edit files directly | Fork and modify |

## Troubleshooting

### Commands not found

Ensure the plugin is properly installed:

```bash
# List installed plugins
/plugin list

# Verify plugin is loaded
/help agentize
```

### Hooks not running

Check that `${CLAUDE_PLUGIN_ROOT}` is set when hooks execute. The plugin manifest at `.claude-plugin/plugin.json` must correctly reference `./hooks/hooks.json`.
