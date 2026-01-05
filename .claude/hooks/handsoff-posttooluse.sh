#!/usr/bin/env bash
# Handsoff PostToolUse hook - Update workflow state on tool usage

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

# Get state file
WORKTREE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$WORKTREE_ROOT" ]]; then
    exit 0
fi

STATE_DIR="$WORKTREE_ROOT/.tmp/claude-hooks/handsoff-sessions"
STATE_FILE="$STATE_DIR/${SESSION_ID}.state"

# Read current state (exit if missing or invalid)
if ! handsoff_read_state "$STATE_FILE"; then
    exit 0
fi

# Parse tool info from JSON params (third argument)
PARAMS="$3"

# Extract tool name (handling both direct tool and Skill wrapper)
TOOL_RAW=$(echo "$PARAMS" | grep -oE '"tool"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"tool"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

# Extract tool name and args based on tool type
TOOL_NAME=""
TOOL_ARGS=""

if [[ "$TOOL_RAW" == "Skill" ]]; then
    # Extract skill name from args.skill
    TOOL_NAME=$(echo "$PARAMS" | grep -oE '"skill"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"skill"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    # Extract skill args from args.args
    TOOL_ARGS=$(echo "$PARAMS" | grep -oE '"args"[[:space:]]*:[[:space:]]*"[^"]*"' | tail -1 | sed 's/.*"args"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
elif [[ "$TOOL_RAW" == "Bash" ]]; then
    # For Bash tool, extract command from args.command
    TOOL_NAME="Bash"
    TOOL_ARGS=$(echo "$PARAMS" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
else
    TOOL_NAME="$TOOL_RAW"
    TOOL_ARGS=$(echo "$PARAMS" | grep -oE '"args"[[:space:]]*:[[:space:]]*\{[^}]*\}' | sed 's/.*"args"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/')
fi

if [[ -z "$TOOL_NAME" ]]; then
    exit 0
fi

# Determine if state transition should occur
NEW_STATE=$(handsoff_transition "$WORKFLOW" "$STATE" "$TOOL_NAME" "$TOOL_ARGS")

# If state changed, update file and log
if [[ "$NEW_STATE" != "$STATE" ]]; then
    handsoff_write_state "$STATE_FILE" "$WORKFLOW" "$NEW_STATE" "$COUNT" "$MAX"

    # Log history entry if debug enabled
    # Update STATE to new value for logging
    export SESSION_ID WORKFLOW COUNT MAX
    STATE="$NEW_STATE"
    export STATE

    DESCRIPTION="$2"
    handsoff_log_history "PostToolUse" "" "" "$DESCRIPTION" "$TOOL_NAME" "$TOOL_ARGS" "$NEW_STATE"
fi
