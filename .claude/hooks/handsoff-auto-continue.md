# Handsoff Auto-Continue Hook

Stop hook that enables automatic workflow continuation in hands-off mode based on workflow state and continuation limit.

## Purpose

When `CLAUDE_HANDSOFF=true`, this hook allows long-running workflows (like `/ultra-planner` and `/issue-to-impl`) to automatically continue after Stop events (milestone creation, task checkpoints) without manual intervention. The hook tracks workflow state and stops auto-continuation when the workflow reaches completion (e.g., PR created, issue updated) or when the continuation limit is reached.

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

**Path**: `.tmp/claude-hooks/handsoff-sessions/<session_id>.state`

**Format**: Single-line colon-separated values: `workflow:state:count:max`

**Example**: `issue-to-impl:implementation:3:10`

**Fields**:
- `workflow`: Workflow name (`ultra-planner`, `issue-to-impl`, or `generic`)
- `state`: Current workflow state (e.g., `planning`, `implementation`, `done`)
- `count`: Current continuation count
- `max`: Maximum continuations allowed (from `HANDSOFF_MAX_CONTINUATIONS`)

**Lifecycle**:
- Created by UserPromptSubmit hook when workflow is detected
- Updated by PostToolUse hook when workflow transitions occur
- Read/updated by Stop hook on each Stop event
- Reset at SessionStart for new sessions
- Not committed to git (excluded by `.gitignore`)

## Behavior

1. **Fail-closed**: If `CLAUDE_HANDSOFF` is not `"true"`, return `ask` immediately
2. **Read state**: Load state file for current session
3. **Check workflow completion**: If state is `done`, return `ask` (workflow complete)
4. **Validate max**: If `HANDSOFF_MAX_CONTINUATIONS` is invalid (non-numeric or ≤ 0), return `ask`
5. **Increment counter**: Add 1 to count field in state
6. **Save state**: Write updated state to file
7. **Decide**: Return `allow` if count ≤ max, otherwise `ask`
8. **Log decision** (if `HANDSOFF_DEBUG=true`): Append decision and reason to history file

**Decision logic**: All decisions are made using bash conditional logic based on state file contents. The hook does not invoke any LLM or API.

## Example Flow

**Session 1: Auto-continue with workflow completion**
```bash
export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10

# UserPromptSubmit: /issue-to-impl 42
# State created: issue-to-impl:docs_tests:0:10

# Stop event 1: state becomes issue-to-impl:docs_tests:1:10, returns "allow"
# Stop event 2: state becomes issue-to-impl:implementation:2:10, returns "allow"
# PostToolUse: open-pr detected, state becomes issue-to-impl:done:2:10
# Stop event 3: state is "done", returns "ask" (workflow complete)
```

**Session 2: Auto-continue reaching limit**
```bash
export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=3

# Stop event 1: count becomes 1, returns "allow"
# Stop event 2: count becomes 2, returns "allow"
# Stop event 3: count becomes 3, returns "allow"
# Stop event 4: count becomes 4, returns "ask" (at limit)
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

Session state initialized in `.claude/hooks/session-init.sh`:
```bash
if [[ "$CLAUDE_HANDSOFF" == "true" ]]; then
    # Generate/read session ID and prepare state directory
    # State files from previous sessions are preserved but not active
fi
```

State tracking coordinated across three hooks:
- `handsoff-userpromptsubmit.sh` - Creates initial state
- `handsoff-posttooluse.sh` - Updates state on workflow events
- `handsoff-auto-continue.sh` - Checks state and decides on continuation

## Debug Logging

When `HANDSOFF_DEBUG=true`, this hook appends a JSONL entry to `.tmp/claude-hooks/handsoff-sessions/history/<session_id>.jsonl` after each Stop decision.

**Fields logged**:
- `event`: `"Stop"`
- `decision`: `"allow"` or `"ask"`
- `reason`: Reason code (see below)
- `description`: Value from hook parameter `$2` (DESCRIPTION)
- `workflow`, `state`, `count`, `max`: Current state file values
- `timestamp`, `session_id`: Standard metadata

**Reason codes**:
- `handsoff_disabled`: `CLAUDE_HANDSOFF` not `"true"`
- `no_state_file`: State file missing
- `workflow_done`: State is `"done"`
- `invalid_max`: `HANDSOFF_MAX_CONTINUATIONS` invalid
- `over_limit`: Count > max
- `under_limit`: Count ≤ max (allow)

**Example entry**:
```json
{"timestamp":"2026-01-05T10:23:45Z","session_id":"abc123","event":"Stop","workflow":"issue-to-impl","state":"implementation","count":"3","max":"10","decision":"allow","reason":"under_limit","description":"Milestone 2 created","tool_name":"","tool_args":"","new_state":""}
```
