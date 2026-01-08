#!/usr/bin/env bash
# Cross-project lol shell function wrapper
# This is a compatibility shim that sources the canonical implementation from src/cli/lol.sh
#
# The canonical lol CLI implementation now lives in src/cli/lol.sh.
# This file exists for backwards compatibility with existing tests and scripts.

# Determine AGENTIZE_HOME if not set
if [ -z "$AGENTIZE_HOME" ]; then
    # Try to derive from script location
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

# All functions (lol, lol_complete, lol_detect_lang, lol_cmd_*) are now available from src/cli/lol.sh
