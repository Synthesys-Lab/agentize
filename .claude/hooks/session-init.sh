#!/usr/bin/env bash

# Set up AGENTIZE_HOME for this project
# This ensures all CLI tools and tests work correctly

# Create setup.sh if it doesn't exist
if [ ! -f setup.sh ]; then
    make setup >/dev/null 2>&1
fi

# Source setup.sh to export AGENTIZE_HOME
if [ -f setup.sh ]; then
    source setup.sh
fi
