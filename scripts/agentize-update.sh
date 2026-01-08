#!/bin/bash
# agentize-update.sh - Wrapper for lol_cmd_update
#
# This is a compatibility wrapper that delegates to the canonical implementation
# in src/cli/lol.sh. Direct script execution is preserved for backwards compatibility.
#
# Environment variables:
#   AGENTIZE_PROJECT_PATH  - Target project directory path
#
# Exit codes:
#   0 - Success
#   1 - Validation failed or update error

# Determine AGENTIZE_HOME if not set
if [ -z "$AGENTIZE_HOME" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    AGENTIZE_HOME="$(dirname "$SCRIPT_DIR")"
    export AGENTIZE_HOME
fi

# Source the canonical implementation
if [ -f "$AGENTIZE_HOME/src/cli/lol.sh" ]; then
    source "$AGENTIZE_HOME/src/cli/lol.sh"
else
    echo "Error: Cannot find canonical lol implementation at $AGENTIZE_HOME/src/cli/lol.sh" >&2
    exit 1
fi

# Execute the update command
lol_cmd_update
