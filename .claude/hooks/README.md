# Hooks

This directory contains Claude Code hooks that execute at specific lifecycle events.

## Purpose

Hooks enable automated behaviors and integrations at key points in the Claude Code workflow without requiring explicit user commands.

## Available Hooks

### session-init.sh
**Event**: SessionStart (beginning of each Claude Code session)

**Purpose**: Initialize project-specific environment and display context-relevant hints

**Actions**:
- Sets up `AGENTIZE_HOME` environment variable
- Runs `make setup` to ensure project is initialized
- Invokes `milestone-resume-hint.sh` to display resume hints when applicable

### milestone-resume-hint.sh
**Event**: Called by session-init.sh

**Purpose**: Display milestone resume hints when hands-off mode is enabled

**Behavior**:
- Only activates when `CLAUDE_HANDSOFF=true`
- Checks if current branch matches `issue-{N}-*` pattern
- Finds latest milestone file in `.milestones/` directory
- Displays formatted hint with natural-language resume examples

**Output example**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Milestone Resume Hint
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Branch: issue-42-add-feature
  Latest milestone: .milestones/issue-42-milestone-2.md

  To resume implementation:
    "Continue from the latest milestone"
    "Resume implementation"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### permission-request.sh
**Event**: Before tool execution (when permission required)

**Purpose**: Auto-approve safe operations in hands-off mode

**Behavior**:
- Checks `CLAUDE_HANDSOFF` environment variable
- Auto-approves safe, local operations (reads, writes, git commands on feature branches)
- Always requires approval for destructive operations (push, force operations)

### post-edit.sh
**Event**: After file edits via Edit tool

**Purpose**: Project-specific post-edit processing (if configured)

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

## Integration Pattern

**Primary hook (session-init.sh)** → **Helper scripts (milestone-resume-hint.sh)**

This pattern keeps the primary hook simple and delegates specific behaviors to focused helper scripts. Each helper can be:
- Tested independently
- Enabled/disabled by removing invocation from primary hook
- Reused by other hooks if needed

## Development Guidelines

When creating new hooks:
1. **Keep primary hooks simple**: Delegate to helper scripts for complex logic
2. **Fail silently**: Hooks should not interrupt user workflow on errors
3. **Check preconditions**: Only execute when relevant (e.g., check environment variables, branch patterns)
4. **Provide clear output**: If displaying information, format it clearly and concisely
5. **Document behavior**: Create companion `.md` file explaining interface and internals
