# Hands-Off Mode

Enable automated workflows without manual permission prompts by setting `CLAUDE_HANDSOFF=true`. This mode auto-approves safe, local operations while maintaining strict safety boundaries for destructive or publish actions.

## Quick Start

```bash
# Enable hands-off mode
export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10  # Optional: set auto-continue limit

# Run full implementation workflow without prompts
/issue-to-impl 42
```

## What Gets Handsoff?


### Permission Requests

It uses `.claude/hooks/permission-request.sh` to aut-approve safe operations.
It is a more powerful solution to `settings.json` as it only supports rigid regex patterns.


### Auto-continuations

Automatically continues workflows by tracking workflow state through `UserPromptSubmit`, `Stop`, and `PostToolUse` hooks. The system detects `/ultra-planner` and `/issue-to-impl` workflows and stops continuation when the workflow reaches completion.

**Session tracking**: Each session is assigned a unique session ID. If `CLAUDE_SESSION_ID` is not available from the hook environment, the system generates and stores a session token in `.tmp/claude-hooks/handsoff-sessions/current-session-id`.

**State file format**: Per-session state is stored at `.tmp/claude-hooks/handsoff-sessions/<session_id>.state` with a single-line format:
```
workflow:state:count:max
```

Example:
```
issue-to-impl:implementation:3:10
```

**Hook behavior**:

- `UserPromptSubmit`: Detects workflow from user prompt (e.g., `/ultra-planner` or `/issue-to-impl`). Initializes state file with workflow name, initial state, count=0, and max from `HANDSOFF_MAX_CONTINUATIONS` (default: 10).

- `PostToolUse`: Tracks tool invocations to update workflow state:
  - **ultra-planner**: `planning` → (Skill open-issue creates placeholder) → `awaiting_details` → (Bash gh issue edit --add-label plan) → `done`
  - **issue-to-impl**: `docs_tests` → (after milestone 1) → `implementation` → (Skill open-pr) → `done`

- `Stop`: Reads state file. If workflow state is `done`, returns `ask` (stop auto-continue). Otherwise, increments count and returns `allow` if count ≤ max, else `ask`.

**Fail-closed**: Invalid state file content or missing workflow defaults to `ask` (manual intervention required).

**Decision logic**: The Stop hook uses bash-based conditional logic to evaluate workflow state and continuation count. It does not invoke any LLM or API; all decisions are made locally based on state file contents.


## Debug Logging

When troubleshooting auto-continuation behavior, enable debug logging with `HANDSOFF_DEBUG=true`. This creates a per-session JSONL history file that records workflow state transitions, Stop decisions, and the reasons behind them.

**Enable debug logging:**
```bash
export HANDSOFF_DEBUG=true
```

**History file location:**
```
.tmp/claude-hooks/handsoff-sessions/history/<session_id>.jsonl
```

**JSONL schema:**
Each line is a JSON object with these fields:
- `timestamp`: ISO 8601 timestamp
- `session_id`: Session identifier
- `event`: Hook event type (`UserPromptSubmit`, `PostToolUse`, `Stop`)
- `workflow`: Workflow name (`ultra-planner`, `issue-to-impl`, or empty)
- `state`: Current workflow state (e.g., `planning`, `implementation`, `done`)
- `count`: Current continuation count
- `max`: Maximum continuations allowed
- `decision`: Hook decision (`allow`, `ask`, or empty for non-Stop events)
- `reason`: Reason code for Stop decisions (see below)
- `description`: Human-readable description from hook parameters
- `tool_name`: Tool name for PostToolUse events (e.g., `Skill`, `Bash`)
- `tool_args`: Tool arguments for PostToolUse events
- `new_state`: New workflow state after PostToolUse transitions

**Reason codes for Stop decisions:**
- `handsoff_disabled`: `CLAUDE_HANDSOFF` not set to `"true"`
- `no_state_file`: State file not found for session
- `workflow_done`: Workflow state is `done` (completion reached)
- `invalid_max`: `HANDSOFF_MAX_CONTINUATIONS` is non-numeric or ≤ 0
- `over_limit`: Continuation count exceeds max limit
- `under_limit`: Count ≤ max, auto-continue allowed

**Example history entry (Stop event):**
```json
{"timestamp":"2026-01-05T10:23:45Z","session_id":"abc123","event":"Stop","workflow":"issue-to-impl","state":"implementation","count":"3","max":"10","decision":"allow","reason":"under_limit","description":"Milestone 2 created","tool_name":"","tool_args":"","new_state":""}
```

**Privacy note:** History logs contain tool arguments and descriptions from hook parameters, which may include user content. Logging is opt-in; disable by unsetting `HANDSOFF_DEBUG` or setting it to any value other than `"true"`.


## Related Documentation

- [Claude Code Pre/Post Hooks](https://code.claude.com/docs/en/hooks)
- [Issue to Implementation Workflow](workflows/issue-to-implementation.md)
- [Issue-to-Impl Tutorial](tutorial/02-issue-to-impl.md)
- [Ultra Planner Workflow](workflows/ultra-planner.md)
