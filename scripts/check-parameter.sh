#!/bin/bash

# Parameter validation utility for Makefile agentize target
# Validates parameters based on the mode (init/update)
#
# Usage: ./scripts/check-parameter.sh <mode> <project_path> <project_name> <project_lang>
#
# Arguments:
#   mode         - Operation mode: "init" or "update"
#   project_path - Path to the project directory (required for all modes)
#   project_name - Project name (required for init mode)
#   project_lang - Project language (required for init mode)
#
# Exit codes:
#   0 - Validation successful
#   1 - Validation failed (missing parameters or invalid template)

set -e

# Get parameters
MODE="$1"
PROJECT_PATH="$2"
PROJECT_NAME="$3"
PROJECT_LANG="$4"

# Validate required PROJECT_PATH (required for all modes)
if [ -z "$PROJECT_PATH" ]; then
    echo "Error: AGENTIZE_PROJECT_PATH is required"
    exit 1
fi

# Mode-specific validation
if [ "$MODE" = "init" ]; then
    # Init mode requires all parameters
    if [ -z "$PROJECT_NAME" ]; then
        echo "Error: AGENTIZE_PROJECT_NAME is required for init mode"
        exit 1
    fi

    if [ -z "$PROJECT_LANG" ]; then
        echo "Error: AGENTIZE_PROJECT_LANG is required for init mode"
        exit 1
    fi

    # Validate template exists for the specified language
    if [ ! -d "templates/$PROJECT_LANG" ]; then
        echo "Error: Template for language '$PROJECT_LANG' not found"
        echo "Available languages: c, cxx, python"
        exit 1
    fi
elif [ "$MODE" = "update" ]; then
    # Update mode only requires PROJECT_PATH (already validated above)
    # No additional validation needed
    :
fi

# Validation successful
exit 0
