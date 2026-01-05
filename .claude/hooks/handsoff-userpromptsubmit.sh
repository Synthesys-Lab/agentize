#!/usr/bin/env bash
# Handsoff UserPromptSubmit hook - Initialize workflow state

# Fail-closed: only activate if hands-off mode enabled
if [[ "$CLAUDE_HANDSOFF" != "true" ]]; then
    exit 0
fi

# Get script directory for sourcing utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/handsoff/state-utils.sh"
source "$SCRIPT_DIR/handsoff/workflows.sh"

# Get session ID
SESSION_ID=$(handsoff_get_session_id)
if [[ -z "$SESSION_ID" ]]; then
    exit 0
fi

# Get state directory and file
WORKTREE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$WORKTREE_ROOT" ]]; then
    exit 0
fi

STATE_DIR="$WORKTREE_ROOT/.tmp/claude-hooks/handsoff-sessions"
STATE_FILE="$STATE_DIR/${SESSION_ID}.state"

# If state file already exists, don't overwrite
if [[ -f "$STATE_FILE" ]]; then
    exit 0
fi

# Parse prompt from JSON params (third argument)
PARAMS="$3"
PROMPT=$(echo "$PARAMS" | grep -oE '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [[ -z "$PROMPT" ]]; then
    exit 0
fi

# Detect workflow
WORKFLOW=$(handsoff_detect_workflow "$PROMPT")
if [[ -z "$WORKFLOW" ]]; then
    # No workflow detected, don't create state
    exit 0
fi

# Get initial state for workflow
INITIAL_STATE=$(handsoff_initial_state "$WORKFLOW")

# Get max continuations
MAX="${HANDSOFF_MAX_CONTINUATIONS:-10}"

# Validate max is positive integer
if ! [[ "$MAX" =~ ^[0-9]+$ ]] || [[ "$MAX" -le 0 ]]; then
    MAX=10
fi

# Create state directory
mkdir -p "$STATE_DIR"

# Write initial state
handsoff_write_state "$STATE_FILE" "$WORKFLOW" "$INITIAL_STATE" 0 "$MAX"

# Log history entry if debug enabled
# Set global variables for logging
export SESSION_ID
export WORKFLOW
STATE="$INITIAL_STATE"
COUNT=0
export STATE COUNT MAX

DESCRIPTION="$2"
handsoff_log_history "UserPromptSubmit" "" "" "$DESCRIPTION" "" "" ""
