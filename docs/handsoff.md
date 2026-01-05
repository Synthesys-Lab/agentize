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


## Related Documentation

- [Claude Code Pre/Post Hooks](https://code.claude.com/docs/en/hooks)
- [Issue to Implementation Workflow](workflows/issue-to-implementation.md)
- [Issue-to-Impl Tutorial](tutorial/02-issue-to-impl.md)
- [Ultra Planner Workflow](workflows/ultra-planner.md)
