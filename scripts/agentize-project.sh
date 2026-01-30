#!/usr/bin/env bash
# agentize-project.sh - Wrapper for _lol_cmd_project
#
# This is a compatibility wrapper that delegates to the canonical implementation
# in src/cli/lol.sh. Direct script execution is preserved for backwards compatibility.
#
# Environment variables (for backward compatibility - will be converted to positional args):
#   AGENTIZE_PROJECT_MODE      - Mode (create, associate, automation)
#   AGENTIZE_PROJECT_ORG       - Organization (for create)
#   AGENTIZE_PROJECT_TITLE     - Project title (for create)
#   AGENTIZE_PROJECT_ASSOCIATE - org/id argument (for associate)
#   AGENTIZE_PROJECT_WRITE_PATH - Output path (for automation)
#
# Exit codes:
#   0 - Success
#   1 - Invalid mode, project not found, or API error

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

# Convert environment variables to positional arguments for backward compatibility
# _lol_cmd_project <mode> [arg1] [arg2]
case "$AGENTIZE_PROJECT_MODE" in
    create)
        _lol_cmd_project "create" "$AGENTIZE_PROJECT_ORG" "$AGENTIZE_PROJECT_TITLE"
        ;;
    associate)
        _lol_cmd_project "associate" "$AGENTIZE_PROJECT_ASSOCIATE"
        ;;
    automation)
        _lol_cmd_project "automation" "$AGENTIZE_PROJECT_WRITE_PATH"
        ;;
    *)
        echo "Error: AGENTIZE_PROJECT_MODE must be set to 'create', 'associate', or 'automation'" >&2
        exit 1
        ;;
esac
