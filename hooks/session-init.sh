#!/usr/bin/env bash

# Skip setup in plugin mode (no project-local setup needed)
if [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
    exit 0
fi

# Project-local mode: Set up AGENTIZE_HOME for this project
# This ensures all CLI tools and tests work correctly

# Create setup.sh if it doesn't exist
if [ ! -f setup.sh ]; then
    make setup >/dev/null 2>&1
fi

# Source setup.sh to export AGENTIZE_HOME
if [ -f setup.sh ]; then
    source setup.sh
fi
