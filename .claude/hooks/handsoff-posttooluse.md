# Handsoff PostToolUse Hook

PostToolUse hook that updates workflow state based on tool invocations in hands-off mode.

## Purpose

When `CLAUDE_HANDSOFF=true`, this hook tracks key tool invocations to update workflow state transitions, enabling workflow-aware auto-continuation that stops when workflows reach completion.

## Event

**PostToolUse** - Triggered after a tool is executed.

## Inputs

### Environment Variables

- `CLAUDE_HANDSOFF` (required): Must be `"true"` to activate state tracking

### Hook Parameters

- `$1` (EVENT): Event type, should be `"PostToolUse"`
- `$2` (DESCRIPTION): Human-readable description
- `$3` (PARAMS): JSON parameters containing tool name and arguments

## Outputs

No direct output. Side effect: Updates state file when workflow transitions occur.

## State File

**Path**: `.tmp/claude-hooks/handsoff-sessions/<session_id>.state`

**Format**: Single-line colon-separated: `workflow:state:count:max`

**Updates workflow state field** while preserving count and max values.

## Behavior

1. **Check hands-off mode**: If `CLAUDE_HANDSOFF` is not `"true"`, exit immediately
2. **Get session ID**: Call `handsoff_get_session_id()` from state-utils.sh
3. **Read current state**: Load state file (exit if missing)
4. **Parse tool info**: Extract tool name and arguments from JSON params
5. **Determine transition**: Call `handsoff_transition()` to compute new state
6. **Update state**: If state changed, write updated state to file

## Workflow Transitions

### ultra-planner workflow

- `planning` + Skill(open-issue) with auto mode → `awaiting_details`
- `awaiting_details` + Skill(open-issue) with update mode → `done`

### issue-to-impl workflow

- `docs_tests` + Skill(milestone) → `implementation`
- `implementation` + Skill(open-pr) → `done`

## Tool Matching

The hook monitors:
- `Skill` tool with `open-issue` skill name
- `Skill` tool with `milestone` skill name
- `Skill` tool with `open-pr` skill name

Tool name and arguments are parsed from the JSON params to determine if a workflow transition should occur.

## Integration

Registered in `.claude/settings.json`:
```json
{
  "hooks": {
    "PostToolUse": {
      "script": ".claude/hooks/handsoff-posttooluse.sh",
      "matcher": "Edit|Write|Skill|Bash"
    }
  }
}
```

Works with:
- `handsoff-userpromptsubmit.sh` - Creates initial state
- `handsoff-auto-continue.sh` - Reads state to decide continuation
