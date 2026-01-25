# Configuration Reference

This document provides the unified configuration reference for Agentize, using YAML-first guidance with environment variable overrides.

## Configuration Files

| File | Purpose | Committed? |
|------|---------|------------|
| `.agentize.yaml` | Project metadata (org, project ID, language) | Yes |
| `.agentize.local.yaml` | Developer settings (credentials, handsoff, Telegram) | No |

**Precedence order (highest to lowest):**
1. CLI arguments (e.g., `--tg-token`)
2. Environment variables (e.g., `TG_API_TOKEN`)
3. `.agentize.local.yaml`
4. Default values

Copy `.agentize.local.example.yaml` to `.agentize.local.yaml` and customize for your setup.

## YAML Configuration Schema

```yaml
# .agentize.local.yaml - Developer-specific local configuration

# Handsoff Mode - Automatic workflow continuation
handsoff:
  enabled: true                    # Enable handsoff auto-continuation
  max_continuations: 10            # Maximum auto-continuations per workflow
  auto_permission: true            # Enable Haiku LLM-based auto-permission
  debug: false                     # Enable debug logging to .tmp/
  supervisor:
    provider: claude               # AI provider (none, claude, codex, cursor, opencode)
    model: opus                    # Model for supervisor
    flags: ""                      # Extra flags for acw

# Telegram Approval - Remote approval via Telegram bot
telegram:
  enabled: false                   # Enable Telegram approval
  token: "123456:ABC..."           # Bot API token from @BotFather
  chat_id: "-100123..."            # Chat/channel ID
  timeout_sec: 60                  # Approval timeout (max: 7200)
  poll_interval_sec: 5             # Poll interval
  allowed_user_ids: "123,456"      # Allowed user IDs (CSV)

# Server Runtime - lol serve configuration
server:
  period: 5m                       # Polling interval
  num_workers: 5                   # Worker pool size

# Workflow Model Assignments
workflows:
  impl:
    model: opus                    # Implementation workflows
  refine:
    model: sonnet                  # Refinement workflows
  dev_req:
    model: sonnet                  # Dev-req planning
  rebase:
    model: haiku                   # PR rebase
```

## Environment Variable Mapping

Environment variables provide overrides for YAML settings. Use them for CI/CD, ad-hoc runs, or when YAML is impractical.

### Handsoff Mode

| YAML Path | Environment Variable | Type | Default |
|-----------|---------------------|------|---------|
| `handsoff.enabled` | `HANDSOFF_MODE` | bool | `true` |
| `handsoff.max_continuations` | `HANDSOFF_MAX_CONTINUATIONS` | int | `10` |
| `handsoff.auto_permission` | `HANDSOFF_AUTO_PERMISSION` | bool | `true` |
| `handsoff.debug` | `HANDSOFF_DEBUG` | bool | `false` |
| `handsoff.supervisor.provider` | `HANDSOFF_SUPERVISOR` | string | `none` |
| `handsoff.supervisor.model` | `HANDSOFF_SUPERVISOR_MODEL` | string | provider-specific |
| `handsoff.supervisor.flags` | `HANDSOFF_SUPERVISOR_FLAGS` | string | `""` |

See [Handsoff Mode](feat/core/handsoff.md) for detailed documentation.

### Telegram Approval

| YAML Path | Environment Variable | Type | Default |
|-----------|---------------------|------|---------|
| `telegram.enabled` | `AGENTIZE_USE_TG` | bool | `false` |
| `telegram.token` | `TG_API_TOKEN` | string | - |
| `telegram.chat_id` | `TG_CHAT_ID` | string | - |
| `telegram.timeout_sec` | `TG_APPROVAL_TIMEOUT_SEC` | int | `60` |
| `telegram.poll_interval_sec` | `TG_POLL_INTERVAL_SEC` | int | `5` |
| `telegram.allowed_user_ids` | `TG_ALLOWED_USER_IDS` | CSV | - |

See [Telegram Approval](feat/permissions/telegram.md) for detailed documentation.

### Server Runtime

| YAML Path | Environment Variable | Type | Default |
|-----------|---------------------|------|---------|
| `server.period` | (CLI only) | string | `5m` |
| `server.num_workers` | (CLI only) | int | `5` |

### Workflow Models

| YAML Path | Environment Variable | Type | Default |
|-----------|---------------------|------|---------|
| `workflows.impl.model` | (YAML only) | string | - |
| `workflows.refine.model` | (YAML only) | string | - |
| `workflows.dev_req.model` | (YAML only) | string | - |
| `workflows.rebase.model` | (YAML only) | string | - |

## Environment-Only Variables

These variables are set by shell scripts or the runtime and do not have YAML equivalents:

| Variable | Type | Description |
|----------|------|-------------|
| `AGENTIZE_HOME` | path | Root path of Agentize installation. Auto-detected by `setup.sh`. |
| `PYTHONPATH` | path | Extended by `setup.sh` to include `$AGENTIZE_HOME/python`. |
| `WT_DEFAULT_BRANCH` | string | Override default branch detection for worktree operations. |
| `WT_CURRENT_WORKTREE` | path | Set automatically by `wt goto` to track current worktree. |
| `TEST_SHELLS` | string | Space-separated list of shells to test (e.g., `"bash zsh"`). |

**Hook path resolution:** When `AGENTIZE_HOME` is set, hooks store session state and logs in `$AGENTIZE_HOME/.tmp/hooked-sessions/`. This enables workflow continuations across worktree switches.

## Type Coercion

| Type | Accepted Values | Example |
|------|-----------------|---------|
| `bool` | `true`, `false`, `1`, `0`, `on`, `off`, `enable`, `disable` | `enabled: true` |
| `int` | Numeric strings or integers | `timeout_sec: 60` |
| `CSV` | Comma-separated values | `allowed_user_ids: "123,456,789"` |

**Note:** The minimal YAML parser does not support native arrays. Use CSV strings for list fields.

## Quick Setup Examples

### Handsoff with Telegram Approval

```yaml
# .agentize.local.yaml
handsoff:
  enabled: true
  max_continuations: 20

telegram:
  enabled: true
  token: "your-bot-token"
  chat_id: "your-chat-id"
  timeout_sec: 300
```

Or via environment (for CI/CD):

```bash
export HANDSOFF_MODE=1
export HANDSOFF_MAX_CONTINUATIONS=20
export AGENTIZE_USE_TG=1
export TG_API_TOKEN="your-bot-token"
export TG_CHAT_ID="your-chat-id"
export TG_APPROVAL_TIMEOUT_SEC=300
```

### Minimal Handsoff Setup

Handsoff mode is enabled by default. To disable:

```yaml
# .agentize.local.yaml
handsoff:
  enabled: false
  auto_permission: false
```

### Development with Debug Logging

```yaml
# .agentize.local.yaml
handsoff:
  debug: true
```

Or:

```bash
source setup.sh  # Sets AGENTIZE_HOME and PYTHONPATH
export HANDSOFF_DEBUG=1
```

### Supervisor Configuration

```yaml
# .agentize.local.yaml
handsoff:
  supervisor:
    provider: claude
    model: opus
    flags: "--timeout 1800"
```

Or:

```bash
export HANDSOFF_SUPERVISOR=claude
export HANDSOFF_SUPERVISOR_MODEL=opus
export HANDSOFF_SUPERVISOR_FLAGS="--timeout 1800"
```

**Provider defaults:**

| Provider | Default Model |
|----------|---------------|
| `claude` | `opus` |
| `codex` | `gpt-5.2-codex` |
| `cursor` | `gpt-5.2-codex-xhigh` |
| `opencode` | `openai/gpt-5.2-codex` |
