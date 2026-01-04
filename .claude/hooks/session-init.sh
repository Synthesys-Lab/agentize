#!/usr/bin/env bash

# Set up AGENTIZE_HOME for this project
# This ensures all CLI tools and tests work correctly

# Resolve PROJECT_ROOT using git (shell-neutral approach)
# Fallback to path-based resolution if git is unavailable
if command -v git >/dev/null 2>&1 && PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    # Git-based resolution succeeded (shell-neutral)
    :
else
    # Fallback: assume this file is in .claude/hooks/
    # Use $0 instead of BASH_SOURCE for better shell compatibility
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null)" || SCRIPT_DIR=""
    if [ -n "$SCRIPT_DIR" ]; then
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    else
        echo "Error: Cannot determine project root"
        return 1
    fi
fi

# Run make setup to ensure setup.sh exists
cd "$PROJECT_ROOT"
make setup >/dev/null 2>&1

# Source setup.sh to export AGENTIZE_HOME
if [ -f "$PROJECT_ROOT/setup.sh" ]; then
    source "$PROJECT_ROOT/setup.sh"
fi

# Show milestone resume hint if applicable
if [ -f "$PROJECT_ROOT/.claude/hooks/milestone-resume-hint.sh" ]; then
    bash "$PROJECT_ROOT/.claude/hooks/milestone-resume-hint.sh"
fi
