# Agentize Server Module

Polling server for GitHub Projects v2 automation.

## Purpose

This module implements a long-running server that:
1. Sends a Telegram startup notification (if configured)
2. Polls GitHub Projects v2 at configurable intervals
3. Identifies issues with "Plan Accepted" status and `agentize:plan` label
4. Spawns worktrees for implementation via `wt spawn`

## Files

- `__init__.py` - Module exports
- `__main__.py` - Main polling loop and CLI entry point

## Usage

```bash
# Via lol CLI (recommended)
lol serve --tg-token=<token> --tg-chat-id=<id> --period=5m

# Direct Python invocation
python -m agentize.server --period=5m --tg-token=<token> --tg-chat-id=<id>
```

Telegram credentials can also be provided via environment variables:
- `TG_API_TOKEN` - Telegram Bot API token
- `TG_CHAT_ID` - Telegram chat ID

CLI arguments take precedence over environment variables.

## Configuration

Reads project association from `.agentize.yaml`:
```yaml
project:
  org: <organization>
  id: <project-number>
```

## Telegram Notifications

When Telegram credentials are configured, the server sends:

### Startup Notification

Sent when the server starts, including hostname, project identifier, polling period, and working directory.

### Worker Assignment Notification

Sent when an issue is successfully assigned to a worker, including issue number, title, worker ID, and GitHub issue link (when `git.remote_url` is configured in `.agentize.yaml`).

## Debug Logging

Set `HANDSOFF_DEBUG=1` to enable detailed logging of issue filtering decisions. See [docs/feat/server.md](../../../docs/feat/server.md#issue-filtering-debug-logs) for output format and examples.
