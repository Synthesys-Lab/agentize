# Telegram Approval

Manual approval workflow via Telegram for hands-off automation.

## Overview

Telegram is the **single final escalation point** in the permission evaluation flow. When all other stages (global rules, workflow auto-allow, Haiku LLM) result in `ask`, the system escalates to Telegram for manual approval. This enables secure hands-off operation by letting you approve/deny tool calls from your phone.

**Position in evaluation order:**
```
Global Rules → Workflow Auto-Allow → Haiku LLM → Telegram (final)
```

Telegram escalation occurs **once at the end**, not at multiple points. This prevents duplicate approval requests and provides a clean escalation path. See [rules.md](rules.md) for the complete evaluation order.

## Configuration

Configure Telegram approval in `.agentize.local.yaml`:

```yaml
telegram:
  enabled: true                    # Enable Telegram approval
  token: "123456:ABC-DEF..."       # Bot API token from @BotFather
  chat_id: "-1001234567890"        # Chat/channel ID
  timeout_sec: 60                  # Approval timeout (default: 60, max: 7200)
  poll_interval_sec: 5             # Poll interval (default: 5)
  allowed_user_ids: "123,456,789"  # Allowed user IDs (CSV, optional)
```

**YAML search order:**
1. Project root `.agentize.local.yaml`
2. `$AGENTIZE_HOME/.agentize.local.yaml`
3. `$HOME/.agentize.local.yaml` (user-wide, created by installer)

### Settings Reference

| YAML Path | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `telegram.enabled` | bool | Yes | `false` | Set to `true` to enable |
| `telegram.token` | string | Yes | - | Telegram Bot API token |
| `telegram.chat_id` | string | Yes | - | Chat ID to send approval requests to |
| `telegram.timeout_sec` | int | No | `60` | Timeout in seconds (max: 7200) |
| `telegram.poll_interval_sec` | int | No | `5` | Poll interval in seconds |
| `telegram.allowed_user_ids` | CSV | No | - | Comma-separated list of allowed user IDs |

## Approval Flow

1. Server sends a message to your Telegram chat with tool details:
   - Tool name
   - Target (command/file path)
   - Session ID (truncated)

2. You respond using inline buttons or text commands:
   - **Buttons**: Tap "Allow" or "Deny"
   - **Commands**: Send `/allow` or `/deny`

3. The original message is updated to show the decision result

4. If no response within timeout, returns `ask` (falls back to Claude Code's default behavior)
