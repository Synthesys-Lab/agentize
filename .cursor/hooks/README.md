# Cursor Hooks

This directory contains Cursor IDE hooks that execute at specific lifecycle events.

## Purpose

Hooks enable automated behaviors and integrations at key points in the Cursor IDE workflow without requiring explicit user commands.

## Available Hooks

### before-prompt-submit.py
**Event**: `beforeSubmitPrompt` (before prompt is sent to Cursor)

**Purpose**: Initialize session state for handsoff mode workflows

**Behavior**:
- Detects `/ultra-planner` and `/issue-to-impl` commands
- Creates session state files in `${AGENTIZE_HOME:-.}/.tmp/hooked-sessions/`
- Extracts optional `issue_no` from command arguments
- Creates issue index files in `by-issue/` subdirectory when issue_no is present
- See [docs/feat/core/handsoff.md](../../docs/feat/core/handsoff.md) for details

**Environment Variables**:
- `HANDSOFF_MODE`: Enable/disable hook (default: `0`, set to `1` to enable)
- `HANDSOFF_DEBUG`: Enable debug logging (default: `0`, set to `1` to enable)
- `AGENTIZE_HOME`: Base directory for session state (default: `.`)

**Issue Number Extraction Patterns**:
- `/issue-to-impl <number>` - Direct command
- `/ultra-planner --refine <number>` - Refinement flag
- `/ultra-planner --from-issue <number>` - From-issue flag

## Hook Invocation Mechanism

Hooks are configured in `.cursor/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [
      {
        "command": "python .cursor/hooks/before-prompt-submit.py"
      }
    ]
  }
}
```

Cursor IDE automatically executes the specified script when the corresponding event occurs.

## Dependencies

### logger.py
Shared logging utility module used by hook scripts.

**Functions**:
- `logger(sid, msg)`: Log debug messages when `HANDSOFF_DEBUG=1`
- `_session_dir()`: Get session directory path using AGENTIZE_HOME fallback
- `_tmp_dir()`: Get tmp directory path using AGENTIZE_HOME fallback

## Development Guidelines

When creating new hooks:
1. **Keep primary hooks simple**: Delegate to helper scripts for complex logic
2. **Fail silently**: Hooks should not interrupt user workflow on errors
3. **Check preconditions**: Only execute when relevant (e.g., check environment variables, branch patterns)
4. **Provide clear output**: If displaying information, format it clearly and concisely
5. **Document behavior**: Create companion `.md` file explaining interface and internals

## Relationship to Claude Hooks

This Cursor hook implementation replicates the functionality of the Claude Code `user-prompt-submit.py` hook (located at `.claude-plugin/hooks/user-prompt-submit.py`). Both hooks:

- Use the same session state file format
- Support the same workflow commands (`/ultra-planner`, `/issue-to-impl`)
- Extract issue numbers using the same regex patterns
- Create session state files in the same location (`${AGENTIZE_HOME:-.}/.tmp/hooked-sessions/`)

The main differences are:
- **Event name**: Cursor uses `beforeSubmitPrompt`, Claude uses `UserPromptSubmit`
- **Configuration format**: Cursor uses simpler JSON structure, Claude uses nested hooks array
- **Path resolution**: Cursor uses relative paths, Claude uses environment variable substitution
