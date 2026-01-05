#!/usr/bin/env bash

# Set up AGENTIZE_HOME for this project
# This ensures all CLI tools and tests work correctly

# Create setup.sh if it doesn't exist
if [ ! -f setup.sh ]; then
    make setup >/dev/null 2>&1
fi

# Source setup.sh to export AGENTIZE_HOME
if [ -f setup.sh ]; then
    source setup.sh
fi

# Initialize hands-off session state when hands-off mode is enabled
if [[ "$CLAUDE_HANDSOFF" == "true" ]]; then
    # Ensure state directory exists
    mkdir -p .tmp/claude-hooks/handsoff-sessions

    # Generate new session ID for this session
    SESSION_ID="session-$(date +%s)-$$"
    echo "$SESSION_ID" > .tmp/claude-hooks/handsoff-sessions/current-session-id

    # Clean up old state files (keep only recent ones)
    find .tmp/claude-hooks/handsoff-sessions -name "*.state" -mtime +7 -delete 2>/dev/null || true

    # Clean up old history files (same retention as state files)
    if [ -d .tmp/claude-hooks/handsoff-sessions/history ]; then
        find .tmp/claude-hooks/handsoff-sessions/history -name "*.jsonl" -mtime +7 -delete 2>/dev/null || true
    fi
fi

# Show milestone resume hint if applicable
if [ -f .claude/hooks/milestone-resume-hint.sh ]; then
    bash .claude/hooks/milestone-resume-hint.sh
fi
