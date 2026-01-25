# Rule-Based Permission Management

Permission rules control tool access through a priority-based evaluation flow.

## Overview

The permission system evaluates tool requests through multiple stages with clear priority ordering. Each stage can return `allow`, `deny`, or `ask`. The key principle is that **global rules always take priority over workflow-specific permissions**.

## Evaluation Order

Permission requests flow through these stages in order:

```
Tool Request
    │
    ▼
┌─────────────────────────────┐
│  1. Global Rules            │  ← First match wins (deny/allow/ask)
│     deny  → DENY (stop)     │
│     allow → ALLOW (stop)    │
│     ask   → fall through    │
└─────────────────────────────┘
    │ (ask or no match)
    ▼
┌─────────────────────────────┐
│  2. Workflow Auto-Allow     │  ← Workflow-scoped patterns
│     allow → ALLOW (stop)    │
│     none  → fall through    │
└─────────────────────────────┘
    │ (no match)
    ▼
┌─────────────────────────────┐
│  3. Haiku LLM               │  ← Context-aware evaluation
│     deny  → DENY (stop)     │
│     allow → ALLOW (stop)    │
│     ask   → fall through    │
└─────────────────────────────┘
    │ (ask)
    ▼
┌─────────────────────────────┐
│  4. Telegram Escalation     │  ← Single final escalation
│     deny  → DENY (stop)     │
│     allow → ALLOW (stop)    │
│     timeout → ASK (prompt)  │
└─────────────────────────────┘
```

## Stage Details

### Stage 1: Global Rules

Global rules are defined in `.claude-plugin/lib/permission/rules.py`. They are evaluated first and take absolute priority.

**Decision behavior:**
- `deny` → Request is denied immediately. No further evaluation.
- `allow` → Request is allowed immediately. No further evaluation.
- `ask` → Falls through to Stage 2 (workflow auto-allow).

**Example rules:**
```python
# Deny rules (highest priority)
('deny', 'Bash', r'^rm\s+-rf'),        # Never allow rm -rf
('deny', 'Bash', r'^sudo\s+'),          # Never allow sudo

# Allow rules
('allow', 'Bash', r'^git\s+status'),    # Always allow git status
('allow', 'Read', r'.*'),               # Allow all file reads

# Ask rules (fall through)
('ask', 'Bash', r'^gh\s+api'),          # Prompt for gh api calls
```

### Stage 2: Workflow Auto-Allow

Workflow-specific permissions apply only when a workflow session is active. These patterns allow known-safe operations within the context of a specific workflow.

**Key constraint:** Workflow auto-allow **cannot override global deny rules**. A workflow cannot auto-allow `rm -rf` if global rules deny it.

**Decision behavior:**
- `allow` → Request is allowed. No further evaluation.
- No match → Falls through to Stage 3 (Haiku LLM).

**Example workflows:**

**setup-viewboard:** Auto-allows GitHub configuration operations:
- `gh auth status` (authentication verification)
- `gh repo view --json owner` (repository lookup)
- `gh api graphql` (project configuration)
- `gh label create --force` (label creation)

**Any workflow:** Auto-allows session state modifications:
- `jq '.state = "done"' ~/.agentize/.tmp/hooked-sessions/{session-id}.json > ... && mv ...` (workflow completion signaling)

This allows workflows to update their session state files to signal completion without requiring permission prompts. The pattern requires literal `.tmp/hooked-sessions/` path and alphanumeric session IDs, preventing path traversal attacks.

These patterns are defined per-workflow and only active during that workflow's session.

### Stage 3: Haiku LLM

When enabled via `handsoff.auto_permission: true` in `.agentize.local.yaml`, Haiku evaluates tool requests using conversation context. This provides intelligent permission decisions for operations not covered by explicit rules.

**Decision behavior:**
- `deny` → Request is denied. No further evaluation.
- `allow` → Request is allowed. No further evaluation.
- `ask` → Falls through to Stage 4 (Telegram).

### Stage 4: Telegram Escalation

Telegram approval is the **single final escalation point** for all `ask` outcomes. When enabled via `telegram.enabled: true` in `.agentize.local.yaml`, the system sends approval requests to Telegram.

**Decision behavior:**
- `deny` → Request is denied.
- `allow` → Request is allowed.
- Timeout/error → Returns `ask` (prompts local user via Claude Code).

**Important:** Telegram escalation occurs **once at the end**, not at multiple points. This prevents duplicate approval requests and provides a clean escalation path.

See [telegram.md](telegram.md) for configuration details.

## Fall-Through Behavior

The `ask` decision has special fall-through behavior:

1. **Global rule returns `ask`** → Continues to workflow auto-allow, then Haiku, then Telegram
2. **Workflow auto-allow has no match** → Continues to Haiku, then Telegram
3. **Haiku returns `ask`** → Continues to Telegram
4. **Telegram times out** → Returns `ask` (prompts local user)

This ensures that uncertain decisions are progressively escalated through more context-aware stages before finally prompting the user.

## Error Handling

The permission system is fail-safe:

- **Rule evaluation errors** → Falls through to Haiku
- **Haiku errors** → Falls through to Telegram
- **Telegram errors** → Returns `ask` (prompts local user)

The system never crashes on errors—it degrades gracefully to user prompts.

## Configuration

### Global Rules

Edit `.claude-plugin/lib/permission/rules.py` to modify global rules. Rules are evaluated in order; first match wins.

### YAML-Configured Rules

Permission rules can also be configured via YAML in `.agentize.yaml` (project-level) and `.agentize.local.yaml` (local overrides).

**YAML Schema:**

```yaml
permissions:
  allow:
    - "^npm run (build|test|lint)"    # Simple string (Bash tool implied)
    - "^make test"
    - pattern: "^cat .*\\.md$"        # Extended format with explicit tool
      tool: Read
  deny:
    - "^npm run deploy:prod"
    - pattern: "^rm -rf"
      tool: Bash
```

**Item formats:**
- **String**: `"^pattern"` - Matches against Bash tool by default
- **Dict**: `{pattern: "^pattern", tool: "ToolName"}` - Explicit tool specification (defaults to `Bash` if omitted)

**Merge order and precedence:**

1. **Hardcoded deny rules always win** - Cannot be overridden by YAML
2. **Project rules** (`.agentize.yaml`) - Shared across team
3. **Local rules** (`.agentize.local.yaml`) - Developer-specific overrides

Rules are evaluated in order: deny → ask → allow. The first match wins.

**Source tracking:** When a rule matches, the source is included in debug logs:
- `rules:hardcoded` - Built-in rule from `rules.py`
- `rules:project` - From `.agentize.yaml`
- `rules:local` - From `.agentize.local.yaml`

### Workflow Auto-Allow

Workflow-specific patterns are defined in `.claude-plugin/lib/permission/determine.py` under workflow-specific pattern lists (e.g., `_SETUP_VIEWBOARD_ALLOW_PATTERNS`).

### YAML Configuration

| YAML Path | Purpose |
|-----------|---------|
| `handsoff.auto_permission` | Enable Haiku LLM evaluation (`true` to enable) |
| `telegram.enabled` | Enable Telegram escalation (`true` to enable) |

See [telegram.md](telegram.md) and [handsoff.md](../core/handsoff.md) for full configuration options.
