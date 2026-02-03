# Configuration Reference

This document provides the unified configuration reference for Agentize. Telegram and handsoff settings use YAML-only configuration.

## Configuration Files

| File | Purpose | Committed? |
|------|---------|------------|
| `.agentize.yaml` | Project metadata (org, project ID, language) | Yes |
| `.agentize.local.yaml` | Developer settings (credentials, handsoff, Telegram) | No |

**Precedence order (highest to lowest):**
1. `.agentize.local.yaml`
2. Default values

**YAML search order:**
1. Project root `.agentize.local.yaml`
2. `$AGENTIZE_HOME/.agentize.local.yaml`
3. `$HOME/.agentize.local.yaml` (user-wide, created by installer)

Copy `.agentize.local.example.yaml` to `.agentize.local.yaml` and customize for your setup, or configure your credentials in `$HOME/.agentize.local.yaml` for use across all projects.

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

# Planner Backends - lol plan stage configuration
planner:
  backend: claude:opus             # Default backend for all stages
  understander: claude:sonnet      # Override understander stage
  bold: claude:opus                # Override bold-proposer stage
  critique: claude:opus            # Override critique stage
  reducer: claude:opus             # Override reducer stage
```

## YAML Settings Reference

All Telegram and handsoff settings are configured via YAML only.

### Handsoff Mode

| YAML Path | Type | Default | Description |
|-----------|------|---------|-------------|
| `handsoff.enabled` | bool | `true` | Enable handsoff auto-continuation |
| `handsoff.max_continuations` | int | `10` | Maximum auto-continuations per workflow |
| `handsoff.auto_permission` | bool | `true` | Enable Haiku LLM-based auto-permission |
| `handsoff.debug` | bool | `false` | Enable debug logging |
| `handsoff.supervisor.provider` | string | `none` | AI provider (none, claude, codex, cursor, opencode) |
| `handsoff.supervisor.model` | string | provider-specific | Model for supervisor |
| `handsoff.supervisor.flags` | string | `""` | Extra flags for acw |

See [Handsoff Mode](feat/core/handsoff.md) for detailed documentation.

### Telegram Approval

| YAML Path | Type | Default | Description |
|-----------|------|---------|-------------|
| `telegram.enabled` | bool | `false` | Enable Telegram approval |
| `telegram.token` | string | - | Bot API token from @BotFather |
| `telegram.chat_id` | string | - | Chat/channel ID |
| `telegram.timeout_sec` | int | `60` | Approval timeout (max: 7200) |
| `telegram.poll_interval_sec` | int | `5` | Poll interval |
| `telegram.allowed_user_ids` | CSV | - | Allowed user IDs (comma-separated) |

See [Telegram Approval](feat/permissions/telegram.md) for detailed documentation.

### Server Runtime

| YAML Path | Type | Default | Description |
|-----------|------|---------|-------------|
| `server.period` | string | `5m` | Polling interval (format: Nm or Ns) |
| `server.num_workers` | int | `5` | Worker pool size |

### Workflow Models

| YAML Path | Type | Default | Description |
|-----------|------|---------|-------------|
| `workflows.impl.model` | string | - | Model for implementation workflows |
| `workflows.refine.model` | string | - | Model for refinement workflows |
| `workflows.dev_req.model` | string | - | Model for dev-req planning |
| `workflows.rebase.model` | string | - | Model for PR rebase |

**Note:** `workflows.impl.model` sets the default model for impl workflows; `lol impl --backend <provider:model>` overrides per run (see `docs/cli/lol.md`).

### Planner Backends

| YAML Path | Type | Default | Description |
|-----------|------|---------|-------------|
| `planner.backend` | string | `claude:opus` | Default backend for all planner stages |
| `planner.understander` | string | - | Override understander stage |
| `planner.bold` | string | - | Override bold-proposer stage |
| `planner.critique` | string | - | Override critique stage |
| `planner.reducer` | string | - | Override reducer stage |

Planner backends use the format `<provider>:<model>` (e.g., `claude:opus`, `claude:sonnet`). Per-stage overrides take precedence over `planner.backend`.

## Environment-Only Variables

These variables are set by shell scripts or the runtime and do not have YAML equivalents:

| Variable | Type | Description |
|----------|------|-------------|
| `AGENTIZE_HOME` | path | Root path of Agentize installation. Auto-detected by `setup.sh`. |
| `AGENTIZE_SHELL_OVERRIDES` | path | Optional shell script sourced after `setup.sh` to override shell functions (testing/stubs). |
| `PYTHONPATH` | path | Extended by `setup.sh` to include `$AGENTIZE_HOME/python`. |
| `WT_DEFAULT_BRANCH` | string | Override default branch detection for worktree operations. |
| `WT_CURRENT_WORKTREE` | path | Set automatically by `wt goto` to track current worktree. |
| `TEST_SHELLS` | string | Space-separated list of shells to test (e.g., `"bash zsh"`). |

**Hook path resolution:** When `AGENTIZE_HOME` is set, hooks store session state and logs in `$AGENTIZE_HOME/.tmp/hooked-sessions/`. This enables workflow continuations across worktree switches.

**Chat session storage:** `$AGENTIZE_HOME/.tmp/acw-sessions/` stores persistent `acw` chat sessions as markdown files with YAML front matter.

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
# .agentize.local.yaml (or $HOME/.agentize.local.yaml for user-wide config)
handsoff:
  enabled: true
  max_continuations: 20

telegram:
  enabled: true
  token: "your-bot-token"
  chat_id: "your-chat-id"
  timeout_sec: 300
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

### Supervisor Configuration

```yaml
# .agentize.local.yaml
handsoff:
  supervisor:
    provider: claude
    model: opus
    flags: "--timeout 1800"
```

**Provider defaults:**

| Provider | Default Model |
|----------|---------------|
| `claude` | `opus` |
| `codex` | `gpt-5.2-codex` |
| `cursor` | `gpt-5.2-codex-xhigh` |
| `opencode` | `openai/gpt-5.2-codex` |
