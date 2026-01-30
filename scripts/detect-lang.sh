#!/bin/bash
# detect-lang.sh - Wrapper for _lol_detect_lang
#
# This is a compatibility wrapper that delegates to the canonical implementation
# in src/cli/lol.sh. Direct script execution is preserved for backwards compatibility.
#
# Usage: ./scripts/detect-lang.sh <project_path>
#
# Arguments:
#   project_path - Path to the project directory to analyze
#
# Output:
#   Writes detected language to stdout: "python", "c", or "cxx"
#   Writes warnings to stderr if unable to detect
#
# Exit codes:
#   0 - Language detected successfully
#   1 - Unable to detect language

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

# Execute the detect language function with the provided argument
_lol_detect_lang "$1"
