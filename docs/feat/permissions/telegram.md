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

### YAML Configuration (Recommended)

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

**Precedence:** Environment variables override YAML settings.

### Environment Variables

Environment variables can override YAML settings:

| Variable | YAML Path | Required | Description |
|----------|-----------|----------|-------------|
| `AGENTIZE_USE_TG` | `telegram.enabled` | Yes | Set to `1`, `true`, or `on` to enable |
| `TG_API_TOKEN` | `telegram.token` | Yes | Telegram Bot API token |
| `TG_CHAT_ID` | `telegram.chat_id` | Yes | Chat ID to send approval requests to |
| `TG_APPROVAL_TIMEOUT_SEC` | `telegram.timeout_sec` | No | Timeout in seconds (default: 60) |
| `TG_POLL_INTERVAL_SEC` | `telegram.poll_interval_sec` | No | Poll interval in seconds (default: 5) |
| `TG_ALLOWED_USER_IDS` | `telegram.allowed_user_ids` | No | Comma-separated list of allowed user IDs |

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
