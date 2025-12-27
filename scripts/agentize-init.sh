#!/bin/bash

set -e

# agentize-init.sh - Initialize new project with agentize templates
#
# Environment variables:
#   AGENTIZE_PROJECT_PATH  - Target project directory path
#   AGENTIZE_PROJECT_NAME  - Project name for template substitutions
#   AGENTIZE_PROJECT_LANG  - Project language (python, c, cxx)
#   AGENTIZE_SOURCE_PATH   - Source code path (optional, defaults to "src")
#
# Exit codes:
#   0 - Success
#   1 - Validation failed or initialization error

# Validate required environment variables
if [ -z "$AGENTIZE_PROJECT_PATH" ]; then
    echo "Error: AGENTIZE_PROJECT_PATH is not set"
    exit 1
fi

if [ -z "$AGENTIZE_PROJECT_NAME" ]; then
    echo "Error: AGENTIZE_PROJECT_NAME is not set"
    exit 1
fi

if [ -z "$AGENTIZE_PROJECT_LANG" ]; then
    echo "Error: AGENTIZE_PROJECT_LANG is not set"
    exit 1
fi

# Set default source path if not specified
SOURCE_PATH="${AGENTIZE_SOURCE_PATH:-src}"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Creating SDK for project: $AGENTIZE_PROJECT_NAME"
echo "Language: $AGENTIZE_PROJECT_LANG"
echo "Source path: $SOURCE_PATH"
echo "Initializing SDK structure..."

# Check if directory exists and is not empty
if [ -d "$AGENTIZE_PROJECT_PATH" ]; then
    if [ -n "$(ls -A "$AGENTIZE_PROJECT_PATH" 2>/dev/null)" ]; then
        echo "Error: Directory '$AGENTIZE_PROJECT_PATH' exists and is not empty."
        echo "Please use an empty directory or a non-existent path for init mode."
        exit 1
    fi
    echo "Directory exists and is empty, proceeding..."
else
    echo "Creating directory '$AGENTIZE_PROJECT_PATH'..."
    mkdir -p "$AGENTIZE_PROJECT_PATH"
fi

# Copy language template
cp -r "$PROJECT_ROOT/templates/$AGENTIZE_PROJECT_LANG/"* "$AGENTIZE_PROJECT_PATH/"

# Copy Claude Code configuration
echo "Copying Claude Code configuration..."
mkdir -p "$AGENTIZE_PROJECT_PATH/.claude"
cp -r "$PROJECT_ROOT/.claude/"* "$AGENTIZE_PROJECT_PATH/.claude/"

# Apply template substitutions to CLAUDE.md
if [ -f "$PROJECT_ROOT/templates/claude/CLAUDE.md.template" ]; then
    sed -e "s/{{PROJECT_NAME}}/$AGENTIZE_PROJECT_NAME/g" \
        -e "s/{{PROJECT_LANG}}/$AGENTIZE_PROJECT_LANG/g" \
        "$PROJECT_ROOT/templates/claude/CLAUDE.md.template" > "$AGENTIZE_PROJECT_PATH/CLAUDE.md"
fi

# Copy documentation templates
cp -r "$PROJECT_ROOT/templates/claude/docs" "$AGENTIZE_PROJECT_PATH/"

# Run bootstrap script if it exists
if [ -f "$AGENTIZE_PROJECT_PATH/bootstrap.sh" ]; then
    echo "Running bootstrap script..."
    chmod +x "$AGENTIZE_PROJECT_PATH/bootstrap.sh"
    (cd "$AGENTIZE_PROJECT_PATH" && \
     AGENTIZE_PROJECT_NAME="$AGENTIZE_PROJECT_NAME" \
     AGENTIZE_PROJECT_PATH="$AGENTIZE_PROJECT_PATH" \
     AGENTIZE_SOURCE_PATH="$SOURCE_PATH" \
     ./bootstrap.sh)
fi

echo "SDK initialized successfully at $AGENTIZE_PROJECT_PATH"
