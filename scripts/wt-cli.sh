#!/usr/bin/env bash
# Worktree management CLI and library
# Can be executed directly or sourced for function access
# This file sources src/cli/wt.sh which contains the actual implementation

# Detect if script is being sourced or executed
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    WT_CLI_SOURCED=false
else
    WT_CLI_SOURCED=true
fi

# Determine the script directory and project root
# Use BASH_SOURCE if available (bash), otherwise try to find via relative path
if [ -n "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Fallback for dash/other shells when sourced
    SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)"
fi

# Try to find PROJECT_ROOT by looking for src/cli/wt.sh
# First, try one level up from scripts/
if [ -f "$SCRIPT_DIR/../src/cli/wt.sh" ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -f "$SCRIPT_DIR/src/cli/wt.sh" ]; then
    # If we're already in project root
    PROJECT_ROOT="$SCRIPT_DIR"
else
    # Fallback: assume we're in scripts/ directory
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# Source the new wt implementation
if [ -f "$PROJECT_ROOT/src/cli/wt.sh" ]; then
    source "$PROJECT_ROOT/src/cli/wt.sh"

    # If executed directly, call wt function with arguments
    if [ "$WT_CLI_SOURCED" = false ]; then
        wt "$@"
        exit $?
    fi

    # Successfully sourced new implementation
    return 0
else
    echo "Error: Cannot find src/cli/wt.sh" >&2
    echo "Expected at: $PROJECT_ROOT/src/cli/wt.sh" >&2
    return 1
fi
