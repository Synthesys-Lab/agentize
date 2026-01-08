#!/bin/bash
# agentize-init.sh - Wrapper for lol_cmd_init
#
# This is a compatibility wrapper that delegates to the canonical implementation
# in src/cli/lol.sh. Direct script execution is preserved for backwards compatibility.
#
# Environment variables:
#   AGENTIZE_PROJECT_PATH  - Target project directory path
#   AGENTIZE_PROJECT_NAME  - Project name for template substitutions
#   AGENTIZE_PROJECT_LANG  - Project language (python, c, cxx)
#   AGENTIZE_SOURCE_PATH   - Source code path (optional, defaults to "src")
#   AGENTIZE_METADATA_ONLY - If "1", create only metadata file
#
# Exit codes:
#   0 - Success
#   1 - Validation failed or initialization error

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

# Execute the init command
lol_cmd_init
