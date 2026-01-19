# Environment Variables Reference

Centralized reference for all environment variables used in Agentize.

## Core Variables

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `AGENTIZE_HOME` | Yes | Path | - | Root path of the Agentize installation. Auto-detected by `setup.sh`. Used by hooks for centralized state storage in `$AGENTIZE_HOME/.tmp/`. |
| `PYTHONPATH` | No | Path | - | Extended by `setup.sh` to include `$AGENTIZE_HOME/python`. |

**Hook path resolution:** When `AGENTIZE_HOME` is set, hooks store session state and logs in `$AGENTIZE_HOME/.tmp/hooked-sessions/`. This enables workflow continuations across worktree switches. If `AGENTIZE_HOME` is unset, hooks use a "soft" fallback: first attempting repo root derivation (via `Makefile` and `src/cli/lol.sh` markers), then falling back to the current worktree (`.`).

## External Agent Selection

Environment variables for controlling which external AI agent and model are used for consensus review.

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `AGENTIZE_EXTERNAL_AGENT` | No | Enum | `auto` | Agent selection: `auto`, `codex`, `agent`, `claude`. |
| `AGENTIZE_EXTERNAL_MODEL` | No | String | `opus` | Model version (e.g., `opus`, `gpt-5.2-codex`). |

### AGENTIZE_EXTERNAL_AGENT

Control which external AI agent CLI is used.

**Used by:**
- `scripts/invoke-external-agent.sh` - Unified agent wrapper
- `.claude-plugin/skills/external-consensus/scripts/external-consensus.sh` - Consensus review
- `.opencode/skills/external-consensus/scripts/external-consensus.sh` - Consensus review

**Default**: `auto` (three-tier fallback: Codex → Agent CLI → Claude)

**Values**:
- `auto`: Try codex first, then agent CLI, then Claude (default)
- `codex`: Force Codex (error if unavailable)
- `agent`: Force Agent CLI (error if unavailable)
- `claude`: Force Claude (skip earlier options)

### AGENTIZE_EXTERNAL_MODEL

Specify the model version to pass to the selected agent.

**Default**: `opus`

**Examples**: `opus`, `gpt-5.2-codex`, `sonnet`

### Usage Examples

```bash
# Force Claude with Opus model (default)
export AGENTIZE_EXTERNAL_AGENT=claude
export AGENTIZE_EXTERNAL_MODEL=opus

# Force Codex with specific model
export AGENTIZE_EXTERNAL_AGENT=codex
export AGENTIZE_EXTERNAL_MODEL=gpt-5.2-codex

# Use auto agent selection with Sonnet model
export AGENTIZE_EXTERNAL_MODEL=sonnet

# Use defaults (auto agent, opus model)
unset AGENTIZE_EXTERNAL_AGENT AGENTIZE_EXTERNAL_MODEL
```

**Error behavior**:
- If agent set but CLI unavailable: Exit with clear error
- If invalid agent value: Exit with error message

## Handsoff Mode

Environment variables for automatic continuation of workflows without manual intervention.

See [Handsoff Mode](feat/core/handsoff.md) for detailed documentation.

| Variable | Required | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `HANDSOFF_MODE` | No | Boolean | `1` | Enable handsoff auto-continuation. Values: `1`, `true`, `on`, `enable`. |
| `HANDSOFF_MAX_CONTINUATIONS` | No | Integer | `10` | Maximum number of auto-continuations per workflow. |
| `HANDSOFF_AUTO_PERMISSION` | No | Boolean | `1` | Enable Haiku LLM-based auto-permission decisions. Values: `1`, `true`, `on`, `enable`. |
| `HANDSOFF_SUPERVISER` | No | Boolean | `0` | Enable Claude-powered dynamic continuation guidance. Values: `1`, `true`, `on`. |
| `HANDSOFF_DEBUG` | No | Boolean | `0` | Enable detailed debug logging to `.tmp/`. Values: `1`, `true`, `on`, `enable`. |

### HANDSOFF_SUPERVISER

Control whether workflows use Claude for dynamic continuation guidance.

**Default**: `0` (disabled, uses static continuation prompts)

**Values**:
- `0`, `false`, `off`: Use static continuation templates (existing behavior, no change)
- `1`, `true`, `on`: Ask Claude for context-aware continuation guidance

**Example**:
```bash
# Enable Claude-powered continuation guidance
export HANDSOFF_SUPERVISER=1

# Run workflow with dynamic prompts
/ultra-planner "your feature request here"
```

**Performance**:
- When disabled (default): No additional latency
- When enabled: +10-30 seconds per continuation (Claude response time)

**Behavior**:
- If Claude call times out or fails, automatically falls back to static templates
- Requires `claude` CLI and authentication
- No new dependencies added
- Fully backwards compatible (default disabled)

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
