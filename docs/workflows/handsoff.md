# Handsoff Mode

Handsoff mode enables automatic continuation of `/ultra-planner` and `/issue-to-impl` workflows without manual user intervention between Claude Code stops.

## Overview

When `HANDSOFF_MODE` is enabled, specific workflows automatically resume after each Claude Code stop until completion or a continuation limit is reached. This allows long-running planning and implementation workflows to proceed autonomously.

**Supported workflows:**
- `/ultra-planner` - Multi-agent debate-based planning (see [ultra-planner.md](ultra-planner.md))
- `/issue-to-impl` - Complete development cycle from issue to PR (see [../tutorial/02-issue-to-impl.md](../tutorial/02-issue-to-impl.md))

## How It Works

### Session State Management

When a supported workflow command is invoked, the `UserPromptSubmit` hook creates a session state file:

```
.tmp/hooked-sessions/{session_id}.json
```

**Initial state structure:**
```json
{
  "workflow": "ultra-planner",
  "state": "initial",
  "continuation_count": 0
}
```

### Auto-Continuation Flow

```
User invokes: /ultra-planner <feature>
       ↓
[UserPromptSubmit Hook]
  - Detects workflow command
  - Creates session state file
  - Initializes continuation_count = 0
       ↓
Claude Code executes workflow
       ↓
Claude Code stops (output limit, token limit, etc.)
       ↓
[Stop Hook]
  - Reads session state file
  - Checks continuation_count < HANDSOFF_MAX_CONTINUATIONS
  - Increments continuation_count
  - Injects workflow-specific auto-continuation prompt
  - Blocks stop with continuation prompt
       ↓
Claude Code automatically resumes with continuation prompt
       ↓
(Repeat until workflow completes or max continuations reached)
```

## Configuration

### Environment Variables

Set in shell environment or `.claude/settings.json`:

**`HANDSOFF_MODE`**
- **Purpose:** Enable/disable handsoff auto-continuation
- **Values:** `1` (enabled), `0` (disabled, default)
- **Example:** `export HANDSOFF_MODE=1`

**`HANDSOFF_MAX_CONTINUATIONS`**
- **Purpose:** Maximum number of auto-continuations per workflow
- **Values:** Integer (default: `10`)
- **Example:** `export HANDSOFF_MAX_CONTINUATIONS=20`

**`HANDSOFF_DEBUG`**
- **Purpose:** Enable detailed debug logging and tool usage tracking
- **Values:** `1` (enabled), `0` (disabled, default)
- **Log file:** `.tmp/hooked-sessions/tool-used.txt`
- **Example:** `export HANDSOFF_DEBUG=1`

### Telegram Approval (Optional)

When configured, enables remote approval of tool usage via Telegram. When a PreToolUse decision is `ask`, the hook sends a Telegram message allowing you to approve or deny from your phone.

**`AGENTIZE_USE_TG`**
- **Purpose:** Enable Telegram approval integration
- **Values:** `1|true|on` (enabled), `0` (disabled, default)
- **Example:** `export AGENTIZE_USE_TG=1`

**`TG_API_TOKEN`**
- **Purpose:** Telegram bot token from @BotFather
- **Example:** `export TG_API_TOKEN=123456:ABC-DEF...`

**`TG_CHAT_ID`**
- **Purpose:** Telegram chat/channel ID for approval messages
- **Example:** `export TG_CHAT_ID=12345678`

**`TG_APPROVAL_TIMEOUT_SEC`**
- **Purpose:** Maximum wait time for Telegram response
- **Default:** `60` seconds
- **Example:** `export TG_APPROVAL_TIMEOUT_SEC=120`

**`TG_POLL_INTERVAL_SEC`**
- **Purpose:** Interval between Telegram API polls
- **Default:** `5` seconds
- **Example:** `export TG_POLL_INTERVAL_SEC=3`

**`TG_ALLOWED_USER_IDS`** (optional)
- **Purpose:** Comma-separated list of Telegram user IDs allowed to approve
- **Example:** `export TG_ALLOWED_USER_IDS=123456,789012`

**Behavior:**
- When Telegram is enabled and configured, `ask` decisions are sent to Telegram
- Approval messages display inline keyboard buttons (`[✅ Allow]` and `[❌ Deny]`) for one-tap approval
- Text commands (`/allow` and `/deny`) still work as fallback for older clients
- Button presses provide immediate acknowledgment and update the original message
- On timeout or API error, falls back to `ask` (prompts local user)
- Missing configuration logs a warning and falls back to `ask`

### Settings.json Configuration

```json
{
  "environment": {
    "HANDSOFF_MODE": "1",
    "HANDSOFF_MAX_CONTINUATIONS": "10",
    "HANDSOFF_DEBUG": "0"
  }
}
```

## Workflow-Specific Behavior

### `/ultra-planner` Workflow

**Goal:** Create a comprehensive implementation plan and post it to GitHub Issue.

**Auto-continuation prompt (injected by Stop hook):**
```
This is an auto-continuation prompt for handsoff mode, it is currently {N}/{MAX} continuations.
The ultimate goal of this workflow is to create a comprehensive plan and post it on GitHub Issue. Have you delivered this?
1. If not, please continue! Try to be as hands-off as possible, avoid asking user design decision questions, and choose the option you recommend most.
2. If you have already delivered the plan, manually stop further continuations.
3. If you do not know what to do next, or you reached the max continuations limit without delivering the plan,
   look at the current branch name to see what issue you are working on. Then stop manually
   and leave a comment on the GitHub Issue for human collaborators to take over.
```

**Completion criteria:** Plan issue created/updated on GitHub.

### `/issue-to-impl` Workflow

**Goal:** Deliver a PR on GitHub that implements the corresponding issue.

**Auto-continuation prompt (injected by Stop hook):**
```
This is an auto-continuation prompt for handsoff mode, it is currently {N}/{MAX} continuations.
The ultimate goal of this workflow is to deliver a PR on GitHub that implements the corresponding issue. Did you have this delivered?
1. If you have completed a milestone but still have more to do, please continue on the next milestone!
2. If you have every coding task done, start the following steps to prepare for PR:
   2.0 Rebase the branch with upstream or origin (priority: upstream/main > upstream/master > origin/main > origin/master).
   2.1 Run the full test suite following the project's test conventions (see CLAUDE.md).
   2.2 Use the code-quality-reviewer agent to review the code quality.
   2.3 If the code review raises concerns, fix the issues and return to 2.1.
   2.4 If the code review is satisfactory, proceed to open the PR.
3. Prepare and create the PR. Do not ask user "Should I create the PR?" - just go ahead and create it!
4. If the PR is successfully created, manually stop further continuations.
```

**Completion criteria:** Pull request created on GitHub with all tests passing.

## Debugging

### Check Session State

View the current session state file:

```bash
cat .tmp/hooked-sessions/{session_id}.json
```

**Example output:**
```json
{
  "workflow": "issue-to-impl",
  "state": "initial",
  "continuation_count": 5
}
```

### View Debug Logs

Enable debug logging and view logs:

```bash
export HANDSOFF_DEBUG=1
tail -f .tmp/hook-debug.log
```

**Example log entries:**
```
[2026-01-07T10:15:23] [abc123] Writing state: {'workflow': 'ultra-planner', 'state': 'initial', 'continuation_count': 0}
[2026-01-07T10:20:45] [abc123] Found existing state file: .tmp/hooked-sessions/abc123.json
[2026-01-07T10:20:45] [abc123] Updating state for continuation: {'workflow': 'ultra-planner', 'state': 'initial', 'continuation_count': 1}
```

### Manual Stop Auto-Continuation

To stop auto-continuation before reaching max limit:

1. Find the session ID from the continuation prompt or logs
2. Edit the session state file:
   ```bash
   # Set continuation_count to max value
   echo '{"workflow": "issue-to-impl", "state": "initial", "continuation_count": 10}' > .tmp/hooked-sessions/{session_id}.json
   ```

3. Or delete the session state file entirely:
   ```bash
   rm .tmp/hooked-sessions/{session_id}.json
   ```

### Resume Session with Human Intervention

If Claude Code leaves a comment on the issue requesting human intervention:

```bash
# Resume the session by session ID
claude -r {session_id}
```

This allows you to review progress, provide guidance, and manually continue the workflow.

## Hook Implementation

Handsoff mode is implemented via three Claude Code hooks (see [.claude/hooks/README.md](../../.claude/hooks/README.md)):

### `pre-tool-use.py`
- **Event:** `PreToolUse` (before tool execution)
- **Purpose:** Enforce permission rules and log tool usage
- **Location:** `.claude/hooks/pre-tool-use.py`

**Key logic:**
- Defines permission rules as Python tuples: `(tool_name, regex_pattern)`
- Matches tool usage against deny → ask → allow rules (first match wins)
- Returns `allow/deny/ask` decision to Claude Code
- Logs tool usage when `HANDSOFF_DEBUG=1`

**Permission rules are defined in Python code instead of `.claude/settings.json`.** This approach:
- Eliminates JSON parsing complexity
- Enables regex pattern matching with Python `re` module
- Provides single source of truth for permissions
- Allows fail-safe defaults (`ask` on errors)

See [.claude/hooks/pre-tool-use.md](../../.claude/hooks/pre-tool-use.md) for rule syntax and interface details.

### `user-prompt-submit.py`
- **Event:** `UserPromptSubmit` (before prompt is sent to Claude Code)
- **Purpose:** Initialize session state for supported workflows
- **Location:** `.claude/hooks/user-prompt-submit.py`

**Key logic:**
- Detects workflow commands: `/ultra-planner`, `/issue-to-impl`
- Creates `.tmp/hooked-sessions/{session_id}.json` with initial state
- Sets `continuation_count = 0`

### `stop.py`
- **Event:** `Stop` (before Claude Code stops execution)
- **Purpose:** Auto-continue workflow with workflow-specific prompts
- **Location:** `.claude/hooks/stop.py`

**Key logic:**
- Reads session state from `.tmp/hooked-sessions/{session_id}.json`
- Checks `continuation_count < HANDSOFF_MAX_CONTINUATIONS`
- Increments `continuation_count`
- Injects workflow-specific continuation prompt
- Blocks stop and triggers auto-resume

**Source of truth:** For exact implementation details and prompt text, refer to `.claude/hooks/pre-tool-use.py`, `.claude/hooks/user-prompt-submit.py` and `.claude/hooks/stop.py`.

## Limitations

- **Non-workflow prompts:** Regular Claude Code usage (not `/ultra-planner` or `/issue-to-impl`) is unaffected
- **Session isolation:** Each session has independent state; switching sessions resets continuation tracking
- **Max continuations:** Workflows stop after reaching `HANDSOFF_MAX_CONTINUATIONS` (default: 10)
- **Error recovery:** If Claude Code encounters critical errors, manual intervention may be required
- **No cross-session state:** Session state is not preserved across Claude Code restarts

## Best Practices

1. **Set appropriate limits:** Adjust `HANDSOFF_MAX_CONTINUATIONS` based on workflow complexity
   - `/ultra-planner`: 5-10 continuations typically sufficient
   - `/issue-to-impl`: 10-20 continuations for complex features

2. **Monitor progress:** Check debug logs or session state periodically for long-running workflows

3. **Human checkpoints:** For critical features, consider manual intervention after key milestones rather than full handsoff mode

4. **Clean up state files:** Periodically clean `.tmp/hooked-sessions/` to remove old session states:
   ```bash
   rm .tmp/hooked-sessions/*.json
   ```

5. **Enable debug logging:** Use `HANDSOFF_DEBUG=1` during initial handsoff setup to understand behavior

## See Also

- [Ultra-Planner Workflow](ultra-planner.md) - Multi-agent planning details
- [Issue-to-Impl Tutorial](../tutorial/02-issue-to-impl.md) - Complete development cycle
- [Hooks README](../../.claude/hooks/README.md) - Hook system overview
