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

### handsoff-userpromptsubmit.sh
**Event**: UserPromptSubmit (when user submits a prompt)

**Purpose**: Initialize per-session workflow state for hands-off mode

**Behavior**:
- Only activates when `CLAUDE_HANDSOFF=true`
- Detects workflow from user prompt (`/ultra-planner` or `/issue-to-impl`)
- Creates state file at `.tmp/claude-hooks/handsoff-sessions/<session_id>.state`
- Initializes with: `workflow:initial_state:0:max`

### handsoff-posttooluse.sh
**Event**: PostToolUse (after tool execution)

**Purpose**: Update workflow state based on tool invocations

**Behavior**:
- Only activates when `CLAUDE_HANDSOFF=true`
- Tracks state transitions for `/ultra-planner` and `/issue-to-impl` workflows
- Updates state file when key workflow milestones are reached
- Example transitions:
  - `open-issue` skill → updates ultra-planner state
  - `milestone` skill → updates issue-to-impl state
  - `open-pr` skill → marks workflow as done

### handsoff-auto-continue.sh
**Event**: Stop (when agent completes a task/milestone checkpoint)

**Purpose**: Auto-continue workflows based on state and continuation limit

**Behavior**:
- Only activates when `CLAUDE_HANDSOFF=true`
- Reads per-session state file to check workflow status
- Returns `ask` if workflow state is `done` (workflow completion)
- Otherwise checks continuation counter against `HANDSOFF_MAX_CONTINUATIONS` (default: 10)
- Returns `allow` if under limit (auto-continues), `ask` if at/over limit
- State stored in `.tmp/claude-hooks/handsoff-sessions/<session_id>.state`

**Inputs**:
- `CLAUDE_HANDSOFF`: Enable/disable hands-off mode
- `HANDSOFF_MAX_CONTINUATIONS`: Integer limit (default: 10, fail-closed on invalid values)
- `HANDSOFF_DEBUG`: Enable debug history logging (set to `"true"` to enable)

**Outputs**:
- `allow`: Auto-continue (workflow not done, under limit)
- `ask`: Require manual input (workflow done, at/over limit, or hands-off disabled)

**State file format**:
- `.tmp/claude-hooks/handsoff-sessions/<session_id>.state`: Single-line format `workflow:state:count:max`

**Debug logging** (when `HANDSOFF_DEBUG=true`):
- `.tmp/claude-hooks/handsoff-sessions/history/<session_id>.jsonl`: JSONL history of state transitions, Stop decisions, and tool invocations

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
