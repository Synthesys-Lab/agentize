#!/usr/bin/env bash

# Set up AGENTIZE_HOME for this project
# This ensures all CLI tools and tests work correctly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Run make setup to ensure setup.sh exists
cd "$PROJECT_ROOT"
make setup >/dev/null 2>&1

# Source setup.sh to export AGENTIZE_HOME
if [ -f "$PROJECT_ROOT/setup.sh" ]; then
    source "$PROJECT_ROOT/setup.sh"
fi

# Show milestone resume hint if applicable
if [ -f "$SCRIPT_DIR/milestone-resume-hint.sh" ]; then
    bash "$SCRIPT_DIR/milestone-resume-hint.sh"
fi
