# Rule-Based Permission Management

Permission rules determine automatic approval, denial, or user-prompting for tool usage during Claude Code sessions. This system enables hands-off automation while maintaining security boundaries.

## Overview

The permission system evaluates tool requests against a rule hierarchy:

```
1. Workflow-scoped rules (highest priority)
2. Static rules: deny → ask → allow (first match wins)
3. Haiku LLM fallback
4. Telegram approval (if enabled)
5. Default: ask user
```

## Rule Priority

### 1. Workflow-Scoped Rules

When a workflow is active (e.g., `/issue-to-impl`, `/setup-viewboard`), workflow-specific rules are evaluated first. These rules enable context-aware auto-allow for operations that are safe within the workflow context.

**Example:** During `/issue-to-impl`, jq updates to the session's own state file are auto-allowed because the workflow needs to track its progress.

### 2. Static Permission Rules

Static rules are defined in `.claude-plugin/lib/permission/rules.py` and evaluated in order:

1. **deny** — Block immediately, no user prompt
2. **ask** — Require explicit user approval
3. **allow** — Auto-approve without prompting

First matching rule wins. If no rule matches, the system falls back to Haiku LLM.

## Rule Definitions

### Deny Rules

Operations that are always blocked:

| Tool | Pattern | Reason |
|------|---------|--------|
| Bash | `^cd` | Directory changes disabled |
| Bash | `^rm -rf` | Destructive file operations |
| Bash | `^sudo` | Privilege escalation |
| Bash | `^git reset` | Destructive git operations |
| Bash | `^git restore` | Destructive git operations |
| Read | `^\.env$` | Environment secrets |
| Read | `^\.env\.` | Environment secrets |
| Read | `.*/licenses/.*` | License files |
| Read | `.*/secrets?/.*` | Secret directories |
| Read | `.*/config/credentials\.json$` | Credential files |
| Read | `/.*\.key$` | Private keys |
| Read | `.*\.pem$` | Certificate files |

### Ask Rules

Operations requiring explicit approval:

| Tool | Pattern | Reason |
|------|---------|--------|
| Bash | `^git push (--force-with-lease\|--force\|-f)` | Force push guardrail |

Force pushes require explicit approval unless verified to target the current issue branch (see "Force Push Verification" below).

### Allow Rules

Operations auto-approved without prompting:

**File Operations:**
- `Write`, `Edit`, `Read` (except denied paths)
- `Grep`, `Glob`, `LSP` — Read-only search tools
- `Task`, `TodoWrite`, `AskUserQuestion` — Agent and UI tools

**Bash Commands:**
- Git read operations: `git status`, `git diff`, `git log`, `git show`
- Git write operations: `git add`, `git rm`, `git push`, `git commit`
- GitHub read operations: `gh pr view`, `gh issue view`, `gh project list`
- Build tools: `make`, `ninja`, `cmake`
- Test execution: `./tests/*.sh`
- File inspection: `cat`, `head`, `tail`, `ls`, `find`, `grep`, `wc`

See `.claude-plugin/lib/permission/rules.py` for the complete list.

## Workflow-Scoped Auto-Allow

### Purpose

Some workflows require specific tool access that would normally need approval. Workflow-scoped rules auto-allow these operations only when the workflow is active.

### Common Permissions (All Workflows)

All workflows automatically allow `jq` writes to the session's own state file at `$AGENTIZE_HOME/.tmp/hooked-sessions/{session_id}.json`. This enables continuation tracking for handsoff mode.

**Security constraints:**
- Only the session's own state file is writable
- Command must match exact pattern: `jq ... {session_file} > {session_file}.tmp && mv ...`
- No wildcard jq writes are permitted

### Workflow-Specific Permissions

#### `/setup-viewboard`

Additional auto-allowed commands:
- `gh auth status` — Authentication verification
- `gh repo view --json owner` — Repository owner lookup
- `gh api graphql` — Project creation and configuration
- `gh label create --force` — Label creation

#### `/issue-to-impl`, `/ultra-planner`, `/plan-to-issue`

These workflows use the common session state permissions only.

### How Workflow Detection Works

1. When a workflow command is invoked, `UserPromptSubmit` hook creates:
   ```
   $AGENTIZE_HOME/.tmp/hooked-sessions/{session_id}.json
   ```

2. This file contains the workflow type:
   ```json
   {"workflow": "issue-to-impl", "state": "initial", "continuation_count": 0}
   ```

3. `PreToolUse` hook reads this file to determine active workflow

4. Workflow-scoped rules are evaluated before static rules

## Force Push Verification

Force pushes to issue branches have special handling:

1. **Pattern match:** `git push --force/-f origin issue-*`
2. **Branch verification:** Current branch must match target issue number
3. **Decision:**
   - Same issue number → `allow`
   - Different issue number → `deny` (prevents pushing to others' branches)
   - Non-issue branch → `ask` (requires approval)

**Example:**
```bash
# On branch issue-42
git push --force origin issue-42      # → allow (same issue)
git push --force origin issue-99      # → deny (different issue)
git push --force origin main          # → ask (not an issue branch)
```

## Adding Custom Rules

### Static Rules

Edit `.claude-plugin/lib/permission/rules.py`:

```python
PERMISSION_RULES = {
    'allow': [
        # Add new allow patterns
        ('Bash', r'^my-safe-command'),
    ],
    'deny': [
        # Add new deny patterns
        ('Bash', r'^dangerous-command'),
    ],
    'ask': [
        # Add new ask patterns
        ('Bash', r'^needs-review'),
    ],
}
```

### Workflow Rules

Edit `.claude-plugin/lib/permission/determine.py`:

1. Add workflow patterns to `_WORKFLOW_ALLOW_RULES`:
   ```python
   _WORKFLOW_ALLOW_RULES = {
       'my-workflow': [
           ('Bash', r'^my-command', None),  # (tool, pattern, optional_verifier)
       ],
   }
   ```

2. Add any required verifier functions if needed

## Debugging

Enable debug logging to trace permission decisions:

```bash
export HANDSOFF_DEBUG=1
```

Log files:
- `$AGENTIZE_HOME/.tmp/hooked-sessions/tool-used.txt` — Auto-approved tools
- `$AGENTIZE_HOME/.tmp/hooked-sessions/tool-haiku-determined.txt` — Haiku decisions
- `$AGENTIZE_HOME/.tmp/hooked-sessions/tool-telegram-determined.txt` — Telegram approvals

## See Also

- [Handsoff Mode](../core/handsoff.md) — Auto-continuation workflows
- [Permission Module](../../../.claude-plugin/lib/permission/README.md) — Implementation details
