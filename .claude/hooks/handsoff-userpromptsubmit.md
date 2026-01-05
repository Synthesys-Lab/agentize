# Handsoff UserPromptSubmit Hook

UserPromptSubmit hook that initializes per-session workflow state for hands-off mode.

## Purpose

When `CLAUDE_HANDSOFF=true` and a workflow command is detected, this hook creates a state file to track the workflow's progress through auto-continuation.

## Event

**UserPromptSubmit** - Triggered when the user submits a prompt to Claude.

## Inputs

### Environment Variables

- `CLAUDE_HANDSOFF` (required): Must be `"true"` to activate state initialization
- `HANDSOFF_MAX_CONTINUATIONS` (optional): Integer limit for auto-continuations (default: 10)

### Hook Parameters

- `$1` (EVENT): Event type, should be `"UserPromptSubmit"`
- `$2` (DESCRIPTION): Human-readable description
- `$3` (PARAMS): JSON parameters containing the user's prompt text

## Outputs

No direct output. Side effect: Creates state file if workflow detected.

## State File

**Path**: `.tmp/claude-hooks/handsoff-sessions/<session_id>.state`

**Format**: Single-line colon-separated: `workflow:state:count:max`

**Initial values**:
- `/ultra-planner` → `ultra-planner:planning:0:10`
- `/issue-to-impl` → `issue-to-impl:docs_tests:0:10`
- Other prompts → No state file created

## Behavior

1. **Check hands-off mode**: If `CLAUDE_HANDSOFF` is not `"true"`, exit immediately
2. **Get session ID**: Call `handsoff_get_session_id()` from state-utils.sh
3. **Parse prompt**: Extract prompt text from JSON params
4. **Detect workflow**: Call `handsoff_detect_workflow()` to identify workflow type
5. **Skip if no workflow**: If workflow is empty/unknown, exit
6. **Determine max**: Use `HANDSOFF_MAX_CONTINUATIONS` or default to 10
7. **Write state**: Create state file with initial state for detected workflow
8. **Log initialization** (if `HANDSOFF_DEBUG=true`): Append entry to history file

## Workflow Detection

- `/ultra-planner` pattern → workflow: `ultra-planner`, initial state: `planning`
- `/issue-to-impl` pattern → workflow: `issue-to-impl`, initial state: `docs_tests`
- No match → no state file created (no auto-continue tracking)

## Integration

Registered in `.claude/settings.json`:
```json
{
  "hooks": {
    "UserPromptSubmit": ".claude/hooks/handsoff-userpromptsubmit.sh"
  }
}
```

Works with:
- `handsoff-posttooluse.sh` - Updates state based on tool usage
- `handsoff-auto-continue.sh` - Checks state to decide continuation

## Debug Logging

When `HANDSOFF_DEBUG=true`, this hook appends a JSONL entry to `.tmp/claude-hooks/handsoff-sessions/history/<session_id>.jsonl` after creating the initial state file.

**Fields logged**:
- `event`: `"UserPromptSubmit"`
- `workflow`: Detected workflow name
- `state`: Initial workflow state
- `count`: `"0"`
- `max`: Configured max continuations
- `description`: Value from hook parameter `$2` (DESCRIPTION)
- `decision`, `reason`, `tool_name`, `tool_args`, `new_state`: Empty strings

**Example entry**:
```json
{"timestamp":"2026-01-05T10:20:00Z","session_id":"abc123","event":"UserPromptSubmit","workflow":"issue-to-impl","state":"docs_tests","count":"0","max":"10","decision":"","reason":"","description":"User submitted prompt","tool_name":"","tool_args":"","new_state":""}
```
