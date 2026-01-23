# Environment Variables Reference

Centralized reference for all environment variables used in Agentize.

## Core Variables

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `AGENTIZE_HOME` | Yes | Path | - | Root path of the Agentize installation. Auto-detected by `setup.sh`. Used by hooks for centralized state storage in `$AGENTIZE_HOME/.tmp/`. |
| `PYTHONPATH` | No | Path | - | Extended by `setup.sh` to include `$AGENTIZE_HOME/python`. |

**Hook path resolution:** When `AGENTIZE_HOME` is set, hooks store session state and logs in `$AGENTIZE_HOME/.tmp/hooked-sessions/`. This enables workflow continuations across worktree switches. If `AGENTIZE_HOME` is unset, hooks use a "soft" fallback: first attempting repo root derivation (via `Makefile` and `src/cli/lol.sh` markers), then falling back to the current worktree (`.`).

## Handsoff Mode

Environment variables for automatic continuation of workflows without manual intervention.

See [Handsoff Mode](feat/core/handsoff.md) for detailed documentation.

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `HANDSOFF_MODE` | No | Boolean | `1` | Enable handsoff auto-continuation. Values: `1`, `true`, `on`, `enable`. |
| `HANDSOFF_MAX_CONTINUATIONS` | No | Integer | `10` | Maximum number of auto-continuations per workflow. |
| `HANDSOFF_AUTO_PERMISSION` | No | Boolean | `1` | Enable Haiku LLM-based auto-permission decisions. Values: `1`, `true`, `on`, `enable`. |
| `HANDSOFF_SUPERVISOR` | No | String | `none` | AI provider for dynamic continuation guidance. Values: `none`, `claude`, `codex`, `cursor`, `opencode`. |
| `HANDSOFF_SUPERVISOR_MODEL` | No | String | Provider-specific | Model name for supervisor (e.g., `sonnet` for claude). |
| `HANDSOFF_SUPERVISOR_FLAGS` | No | String | (empty) | Extra flags to pass to acw (e.g., `--timeout 1800`). |
| `HANDSOFF_DEBUG` | No | Boolean | `0` | Enable detailed debug logging to `.tmp/`. Values: `1`, `true`, `on`, `enable`. |

### HANDSOFF_SUPERVISOR

Control which AI provider is used for dynamic continuation guidance.

**Default**: `none` (disabled, uses static continuation prompts)

**Values**:
- `none`: Use static continuation templates (existing behavior, no change)
- `claude`: Use Claude CLI for context-aware continuation guidance
- `codex`: Use Codex CLI for continuation guidance
- `cursor`: Use Cursor Agent CLI for continuation guidance
- `opencode`: Use Opencode CLI for continuation guidance

**Related Variables**:
- `HANDSOFF_SUPERVISOR_MODEL`: Model name for the provider (default: provider-specific)
- `HANDSOFF_SUPERVISOR_FLAGS`: Extra flags passed to acw (default: empty)

**Provider Defaults**:
| Provider | Default Model |
|----------|---------------|
| `claude` | `sonnet` |
| `codex` | `gpt-5.2-codex` |
| `cursor` | `claude-3.5-sonnet` |
| `opencode` | `sonnet` |

**Examples**:
```bash
# Use Claude as supervisor (with default model)
export HANDSOFF_SUPERVISOR=claude

# Use Codex as supervisor with specific model
export HANDSOFF_SUPERVISOR=codex
export HANDSOFF_SUPERVISOR_MODEL=gpt-5.2-codex

# Use Claude with extra flags
export HANDSOFF_SUPERVISOR=claude
export HANDSOFF_SUPERVISOR_FLAGS="--timeout 1800"

# Disable supervisor (default)
export HANDSOFF_SUPERVISOR=none
```

**Performance**:
- When disabled (default): No additional latency
- When enabled: +10-30 seconds per continuation (provider response time)

**Behavior**:
- If provider call times out or fails, automatically falls back to static templates
- Requires the respective CLI (claude, codex, agent, or opencode) and authentication
- Uses `acw` (Agent CLI Wrapper) under the hood for unified invocation

## Telegram Approval

Environment variables for remote approval via Telegram.

See [Telegram Approval](feat/permissions/telegram.md) for detailed documentation.

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `AGENTIZE_USE_TG` | No | Boolean | `0` | Enable Telegram approval integration. Values: `1`, `true`, `on`. |
| `TG_API_TOKEN` | Conditional | String | - | Telegram Bot API token from @BotFather. Required when `AGENTIZE_USE_TG=1`. Overrides `.agentize.local.yaml` `telegram.token`. |
| `TG_CHAT_ID` | Conditional | String | - | Telegram chat/channel ID for approval messages. Required when `AGENTIZE_USE_TG=1`. Overrides `.agentize.local.yaml` `telegram.chat_id`. |
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

Handsoff mode is enabled by default. To disable it, set:

```bash
export HANDSOFF_MODE=0
export HANDSOFF_AUTO_PERMISSION=0
```

Override max continuations (optional):

```bash
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
