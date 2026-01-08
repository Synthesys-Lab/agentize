# PreToolUse Hook Interface

Logs tool usage and enforces permission rules for Claude Code tools.

## Purpose

Provides unified logging and permission enforcement for handsoff mode workflows without requiring separate hooks or JSON configuration.

## Input

JSON via stdin:

```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "git status"
  },
  "session_id": "abc123"
}
```

## Output

JSON to stdout:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
```

**Permission decisions:**
- `allow` - Tool execution proceeds without user intervention
- `deny` - Tool execution blocked (user sees error)
- `ask` - User prompted to approve/deny

## Permission Rule Syntax

Rules are defined as Python tuples in the `PERMISSION_RULES` dict:

```python
PERMISSION_RULES = {
    'allow': [
        ('Bash', r'^git (status|diff|log)'),
        ('Read', r'^/Users/were/repos/.*'),
    ],
    'deny': [
        ('Read', r'.*\.(env|key|pem)$'),
    ],
    'ask': [
        ('Bash', r'^git (push|commit)'),
    ]
}
```

**Rule structure:**
- First element: Tool name (exact match)
- Second element: Regex pattern (matched against tool target)

**Rule priority (first match wins):**
1. Deny rules checked first
2. Ask rules checked second
3. Allow rules checked last
4. No match defaults to `ask`

## Tool Target Extraction

The hook extracts targets from tool_input for pattern matching:

| Tool | Target Extraction |
|------|------------------|
| Bash | `command` field (env vars stripped) |
| Read/Write/Edit | `file_path` field |
| Skill | `skill` field |
| WebFetch | `url` field |
| WebSearch | `query` field |
| Others | First 100 chars of tool_input JSON |

## Bash Command Parsing

Commands with leading environment variables are normalized before matching:

**Input:** `ENV=value OTHER=x git status`
**Matched against:** `git status`

**Regex for env stripping:** `r'^(\w+=\S+\s+)+'`

This ensures rules like `r'^git status'` match both:
- `git status`
- `ENV=foo git status`

## Shell Prefix Stripping

Commands with leading shell option prefixes are normalized before matching:

**Input:** `set -x && git status`
**Matched against:** `git status`

**Supported prefixes:**
- `set -x && ` (debug tracing)
- `set -e && ` (exit on error)
- `set -o pipefail && ` (pipeline error handling)

Multiple prefixes are also handled:
- `set -x && set -e && git status` → `git status`

**Regex:** `r'^(set\s+-[exo]\s+[a-z]*\s*&&\s*)+'`

## Fail-Safe Behavior

Errors during permission checking default to `ask`:

- Regex compilation error → `ask`
- Pattern matching exception → `ask`
- Missing target field → `ask`

This prevents hook failures from blocking Claude Code execution.

## Logging Behavior

When `HANDSOFF_DEBUG=1`:
- Writes tool usage to `.tmp/hooked-sessions/tool-used.txt`
- Format: `[timestamp] [session_id] [workflow] tool | target`
- Preserved regardless of permission decision

## Telegram Approval Integration

When `AGENTIZE_USE_TG=1|true|on` is set with valid `TG_API_TOKEN` and `TG_CHAT_ID`, the hook can request remote approval via Telegram for `ask` decisions.

### Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `AGENTIZE_USE_TG` | Yes | Enable Telegram (`1\|true\|on`) |
| `TG_API_TOKEN` | Yes | Bot token from @BotFather |
| `TG_CHAT_ID` | Yes | Chat ID for approval messages |
| `TG_APPROVAL_TIMEOUT_SEC` | No | Max wait time (default: 60) |
| `TG_POLL_INTERVAL_SEC` | No | Poll interval (default: 5) |
| `TG_ALLOWED_USER_IDS` | No | Comma-separated allowed user IDs |

### Decision Flow

```
Permission check result = 'ask'
        ↓
Telegram enabled? (AGENTIZE_USE_TG=1|true|on)
        ↓ No → return 'ask' (prompt local user)
        ↓ Yes
TG_API_TOKEN and TG_CHAT_ID set?
        ↓ No → log warning, return 'ask'
        ↓ Yes
Send approval request to Telegram
        ↓
Poll for response (up to TG_APPROVAL_TIMEOUT_SEC)
        ↓
Response received?
        ↓ No (timeout) → return 'ask'
        ↓ Yes
Parse response: /allow → 'allow', /deny → 'deny'
        ↓
Return decision
```

### Message Format

Approval request sent to Telegram:
```
🔧 Tool Approval Request

Tool: Bash
Target: git push origin main
Session: abc123

Reply /allow or /deny
```

### Error Handling

- Missing `TG_API_TOKEN` or `TG_CHAT_ID`: Logs warning, returns `ask`
- Telegram API error: Logs error, returns `ask`
- Timeout (no response): Returns `ask`
- Invalid response (not /allow or /deny): Continues polling until timeout
