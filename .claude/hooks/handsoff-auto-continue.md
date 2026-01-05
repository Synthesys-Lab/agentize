# Handsoff Auto-Continue Hook

Stop hook that enables automatic workflow continuation in hands-off mode up to a configured limit.

## Purpose

When `CLAUDE_HANDSOFF=true`, this hook allows long-running workflows (like `/ultra-planner` and `/issue-to-impl`) to automatically continue after Stop events (milestone creation, task checkpoints) without manual intervention, up to a bounded limit.

## Event

**Stop** - Triggered when the agent completes a task or reaches a milestone checkpoint.

## Inputs

### Environment Variables

- `CLAUDE_HANDSOFF` (required): Must be `"true"` to activate auto-continue
- `HANDSOFF_MAX_CONTINUATIONS` (optional): Integer limit for auto-continuations
  - Default: `10`
  - Must be a positive integer
  - Non-numeric or non-positive values disable auto-continue (fail-closed)

### Hook Parameters

- `$1` (EVENT): Event type, should be `"Stop"`
- `$2` (DESCRIPTION): Human-readable description of the stop event
- `$3` (PARAMS): JSON parameters (not currently used)

## Outputs

Returns one of:
- `allow` - Auto-continue (counter under limit)
- `ask` - Require manual input (counter at/over limit, or hands-off disabled)

## State File

**Path**: `.tmp/claude-hooks/handsoff-sessions/continuation-count`

**Format**: Plain integer (e.g., `3`)

**Lifecycle**:
- Created on first Stop event when hands-off mode is enabled
- Incremented on each Stop event
- Reset to 0 on SessionStart (via session-init.sh) when hands-off mode is enabled
- Not committed to git (excluded by `.gitignore`)

## Behavior

1. **Fail-closed**: If `CLAUDE_HANDSOFF` is not `"true"`, return `ask` immediately
2. **Validate max**: If `HANDSOFF_MAX_CONTINUATIONS` is invalid (non-numeric or ≤ 0), return `ask`
3. **Read counter**: Load current count from state file (default: 0 if file missing)
4. **Increment**: Add 1 to counter
5. **Save**: Write updated count to state file
6. **Decide**: Return `allow` if count ≤ max, otherwise `ask`

## Example Flow

**Session 1: Auto-continue enabled**
```bash
export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=3

# Stop event 1: count becomes 1, returns "allow"
# Stop event 2: count becomes 2, returns "allow"
# Stop event 3: count becomes 3, returns "allow"
# Stop event 4: count becomes 4, returns "ask" (at limit)
```

**Session 2: Counter reset**
```bash
# SessionStart hook resets counter to 0
# Stop event 1: count becomes 1, returns "allow" (fresh start)
```

## Integration

Registered in `.claude/settings.json`:
```json
{
  "hooks": {
    "Stop": ".claude/hooks/handsoff-auto-continue.sh"
  }
}
```

Counter reset in `.claude/hooks/session-init.sh`:
```bash
if [[ "$CLAUDE_HANDSOFF" == "true" ]]; then
    rm -f .tmp/claude-hooks/handsoff-sessions/continuation-count
fi
```
