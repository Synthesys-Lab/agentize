#!/usr/bin/env bash
# Stop hook for auto-continue in hands-off mode
# Returns 'allow' to auto-continue, 'ask' to require manual input

# Event and parameters (from Claude Code hook system)
EVENT="$1"
DESCRIPTION="$2"
PARAMS="$3"

# State directory and counter file (fixed path)
STATE_DIR=".tmp/claude-hooks/handsoff-sessions"
COUNTER_FILE="$STATE_DIR/continuation-count"

# Default max continuations
DEFAULT_MAX=10

# Fail-closed: only activate when hands-off mode is enabled
if [[ "$CLAUDE_HANDSOFF" != "true" ]]; then
    echo "ask"
    exit 0
fi

# Get max continuations from environment (default: 10)
MAX_CONTINUATIONS="${HANDSOFF_MAX_CONTINUATIONS:-$DEFAULT_MAX}"

# Validate max continuations: must be a positive integer
if ! [[ "$MAX_CONTINUATIONS" =~ ^[0-9]+$ ]] || [[ "$MAX_CONTINUATIONS" -le 0 ]]; then
    # Invalid value: fail-closed
    echo "ask"
    exit 0
fi

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Read current count (default: 0 if file doesn't exist)
if [[ -f "$COUNTER_FILE" ]]; then
    CURRENT_COUNT=$(cat "$COUNTER_FILE")
    # Validate counter file contents
    if ! [[ "$CURRENT_COUNT" =~ ^[0-9]+$ ]]; then
        CURRENT_COUNT=0
    fi
else
    CURRENT_COUNT=0
fi

# Increment counter
CURRENT_COUNT=$((CURRENT_COUNT + 1))

# Save updated count
echo "$CURRENT_COUNT" > "$COUNTER_FILE"

# Check if under limit
if [[ "$CURRENT_COUNT" -le "$MAX_CONTINUATIONS" ]]; then
    echo "allow"
else
    echo "ask"
fi
