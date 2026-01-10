# Environment Variables Reference

Centralized reference for all environment variables used in Agentize.

## Core Variables

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `AGENTIZE_HOME` | Yes | Path | - | Root path of the Agentize installation. Auto-detected by `setup.sh`. |
| `PYTHONPATH` | No | Path | - | Extended by `setup.sh` to include `$AGENTIZE_HOME/python`. |

## Handsoff Mode

Environment variables for automatic continuation of workflows without manual intervention.

See [Handsoff Mode](feat/core/handsoff.md) for detailed documentation.

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `HANDSOFF_MODE` | No | Boolean | `0` | Enable handsoff auto-continuation. Values: `1`, `true`, `on`, `enable`. |
| `HANDSOFF_MAX_CONTINUATIONS` | No | Integer | `10` | Maximum number of auto-continuations per workflow. |
| `HANDSOFF_AUTO_PERMISSION` | No | Boolean | `0` | Enable Haiku LLM-based auto-permission decisions. Values: `1`, `true`, `on`, `enable`. |
| `HANDSOFF_DEBUG` | No | Boolean | `0` | Enable detailed debug logging to `.tmp/`. Values: `1`, `true`, `on`, `enable`. |

## Telegram Approval

Environment variables for remote approval via Telegram.

See [Telegram Approval](feat/permissions/telegram.md) for detailed documentation.

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `AGENTIZE_USE_TG` | No | Boolean | `0` | Enable Telegram approval integration. Values: `1`, `true`, `on`. |
| `TG_API_TOKEN` | Conditional | String | - | Telegram Bot API token from @BotFather. Required when `AGENTIZE_USE_TG=1`. |
| `TG_CHAT_ID` | Conditional | String | - | Telegram chat/channel ID for approval messages. Required when `AGENTIZE_USE_TG=1`. |
| `TG_APPROVAL_TIMEOUT_SEC` | No | Integer | `60` | Maximum wait time for Telegram response in seconds. Maximum: 7200 (2 hours). |
| `TG_POLL_INTERVAL_SEC` | No | Integer | `5` | Interval between Telegram API polls in seconds. |
| `TG_ALLOWED_USER_IDS` | No | String | - | Comma-separated list of Telegram user IDs allowed to approve. |

## CLI (`wt` Command)

Environment variables for the git worktree helper.

See [wt Command](feat/cli/wt.md) for detailed documentation.

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `WT_DEFAULT_BRANCH` | No | String | `main`/`master` | Override default branch detection for worktree operations. |
| `WT_CURRENT_WORKTREE` | No | Path | - | Set automatically by `wt goto` to track current worktree path. |

## Testing

Environment variables for running the test suite.

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `TEST_SHELLS` | No | String | - | Space-separated list of shells to test (e.g., `"bash zsh"`). |

## Quick Reference

### Minimal Handsoff Setup

```bash
export HANDSOFF_MODE=1
export HANDSOFF_MAX_CONTINUATIONS=10
```

### Handsoff with Telegram Approval

```bash
export HANDSOFF_MODE=1
export HANDSOFF_MAX_CONTINUATIONS=20
export AGENTIZE_USE_TG=1
export TG_API_TOKEN="your-bot-token"
export TG_CHAT_ID="your-chat-id"
export TG_APPROVAL_TIMEOUT_SEC=300
```

### Development Setup

```bash
source setup.sh  # Sets AGENTIZE_HOME and PYTHONPATH automatically
export HANDSOFF_DEBUG=1  # Enable debug logging
```
