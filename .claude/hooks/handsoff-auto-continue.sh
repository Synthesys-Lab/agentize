#!/usr/bin/env bash
# Stop hook for auto-continue in hands-off mode
# Returns 'allow' to auto-continue, 'ask' to require manual input

# Event and parameters (from Claude Code hook system)
EVENT="$1"
DESCRIPTION="$2"
PARAMS="$3"

# Get script directory for sourcing utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/handsoff/state-utils.sh"
source "$SCRIPT_DIR/handsoff/workflows.sh"

# Fail-closed: only activate when hands-off mode is enabled
if [[ "$CLAUDE_HANDSOFF" != "true" ]]; then
    # Log reason if debug enabled (but no state available yet)
    export SESSION_ID=""
    export WORKFLOW="" STATE="" COUNT="" MAX=""
    handsoff_log_history "Stop" "ask" "handsoff_disabled" "$DESCRIPTION" "" "" ""
    echo "ask"
    exit 0
fi

# Get session ID
SESSION_ID=$(handsoff_get_session_id)
if [[ -z "$SESSION_ID" ]]; then
    echo "ask"
    exit 0
fi

# Get state file
WORKTREE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$WORKTREE_ROOT" ]]; then
    echo "ask"
    exit 0
fi

STATE_DIR="$WORKTREE_ROOT/.tmp/claude-hooks/handsoff-sessions"
STATE_FILE="$STATE_DIR/${SESSION_ID}.state"

# Read current state (fail-closed if missing or invalid)
if ! handsoff_read_state "$STATE_FILE"; then
    export SESSION_ID WORKFLOW="" STATE="" COUNT="" MAX=""
    handsoff_log_history "Stop" "ask" "no_state_file" "$DESCRIPTION" "" "" ""
    echo "ask"
    exit 0
fi

# Export for logging
export SESSION_ID WORKFLOW STATE COUNT MAX

# Check if workflow is done
if handsoff_is_done "$WORKFLOW" "$STATE"; then
    handsoff_log_history "Stop" "ask" "workflow_done" "$DESCRIPTION" "" "" ""
    echo "ask"
    exit 0
fi

# Validate max continuations from state file
if ! [[ "$MAX" =~ ^[0-9]+$ ]] || [[ "$MAX" -le 0 ]]; then
    handsoff_log_history "Stop" "ask" "invalid_max" "$DESCRIPTION" "" "" ""
    echo "ask"
    exit 0
fi

# Increment counter
NEW_COUNT=$((COUNT + 1))

# Save updated state with incremented count
handsoff_write_state "$STATE_FILE" "$WORKFLOW" "$STATE" "$NEW_COUNT" "$MAX"

# Update COUNT for logging
COUNT="$NEW_COUNT"
export COUNT

# Check if under limit
if [[ "$NEW_COUNT" -le "$MAX" ]]; then
    handsoff_log_history "Stop" "allow" "under_limit" "$DESCRIPTION" "" "" ""
    echo "allow"
else
    handsoff_log_history "Stop" "ask" "over_limit" "$DESCRIPTION" "" "" ""
    echo "ask"
fi
