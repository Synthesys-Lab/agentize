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
7. **Log transition** (if `HANDSOFF_DEBUG=true`): Append entry to history file

## Workflow Transitions

### ultra-planner workflow

- `planning` + Skill(open-issue) with auto mode → `awaiting_details`
- `awaiting_details` + Bash(gh issue edit --add-label plan) → `done`

### issue-to-impl workflow

- `docs_tests` + Skill(milestone) → `implementation`
- `implementation` + Skill(open-pr) → `done`

## Tool Matching

The hook monitors:
- `Skill` tool with `open-issue` skill name (for placeholder creation)
- `Skill` tool with `milestone` skill name (for issue-to-impl)
- `Skill` tool with `open-pr` skill name (for issue-to-impl)
- `Bash` tool with `gh issue edit --add-label plan` command (for ultra-planner finalization)

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

## Debug Logging

When `HANDSOFF_DEBUG=true`, this hook appends a JSONL entry to `.tmp/claude-hooks/handsoff-sessions/history/<session_id>.jsonl` after updating workflow state.

**Fields logged**:
- `event`: `"PostToolUse"`
- `tool_name`: Tool name from params (e.g., `"Skill"`, `"Bash"`)
- `tool_args`: Tool arguments (e.g., skill name, command)
- `new_state`: New workflow state after transition
- `workflow`, `state`, `count`, `max`: State file values (state reflects new value)
- `description`: Value from hook parameter `$2` (DESCRIPTION)
- `decision`, `reason`: Empty strings

**Example entry**:
```json
{"timestamp":"2026-01-05T10:22:30Z","session_id":"abc123","event":"PostToolUse","workflow":"issue-to-impl","state":"implementation","count":"0","max":"10","decision":"","reason":"","description":"Tool executed","tool_name":"Skill","tool_args":"milestone","new_state":"implementation"}
```
