# Hooks

This directory contains Claude Code hooks that execute at specific lifecycle events.

## Purpose

Hooks enable automated behaviors and integrations at key points in the Claude Code workflow without requiring explicit user commands.

## Available Hooks

### session-init.sh
**Event**: SessionStart (beginning of each Claude Code session)

**Purpose**: Initialize project-specific environment

**Actions**:
- Sets up `AGENTIZE_HOME` environment variable
- Runs `make setup` to ensure project is initialized

### permission-request.sh
**Event**: Before tool execution (when permission required)

**Purpose**: Default permission policy for tool execution

**Behavior**:
- Returns `ask` decision for all tool executions
- User must approve each tool use through Claude Code's permission system

### post-edit.sh
**Event**: After file edits via Edit tool

**Purpose**: Project-specific post-edit processing (if configured)

### pre-tool-use.py
**Event**: PreToolUse (before tool execution)

**Purpose**: Thin wrapper delegating to `python/agentize/permission/` module

**Behavior**:
- Delegates to `agentize.permission.determine()` for permission decisions
- Rules are sourced from `python/agentize/permission/rules.py`
- Returns `allow/deny/ask` decision based on pattern matching
- Logs tool usage when `HANDSOFF_DEBUG=1`
- Falls back to `ask` on import/execution errors
- See [pre-tool-use.md](pre-tool-use.md) for interface details

### user-prompt-submit.py
**Event**: UserPromptSubmit (before prompt is sent to Claude Code)

**Purpose**: Initialize session state for handsoff mode workflows

**Behavior**:
- Detects `/ultra-planner` and `/issue-to-impl` commands
- Creates session state files in `${AGENTIZE_HOME:-.}/.tmp/hooked-sessions/`
- Extracts optional `issue_no` from command arguments
- See [docs/feat/core/handsoff.md](../../docs/feat/core/handsoff.md) for details

### stop.py
**Event**: Stop (before Claude Code stops execution)

**Purpose**: Auto-continue workflows in handsoff mode

**Behavior**:
- Reads session state from `${AGENTIZE_HOME:-.}/.tmp/hooked-sessions/`
- Increments continuation count and checks limits
- Injects workflow-specific continuation prompts
- See [docs/feat/core/handsoff.md](../../docs/feat/core/handsoff.md) for details

## Hook Invocation Mechanism

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": ".claude/hooks/session-init.sh"
  }
}
```

Claude Code automatically executes the specified script when the corresponding event occurs.

## Development Guidelines

When creating new hooks:
1. **Keep primary hooks simple**: Delegate to helper scripts for complex logic
2. **Fail silently**: Hooks should not interrupt user workflow on errors
3. **Check preconditions**: Only execute when relevant (e.g., check environment variables, branch patterns)
4. **Provide clear output**: If displaying information, format it clearly and concisely
5. **Document behavior**: Create companion `.md` file explaining interface and internals
