#!/bin/bash

# Language detection utility for projects
# Detects project language based on file structure and common patterns
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

set -e

# Get project path
PROJECT_PATH="$1"

# Validate project path is provided
if [ -z "$PROJECT_PATH" ]; then
    echo "Error: Project path is required" >&2
    exit 1
fi

# Detect Python projects
if [ -f "$PROJECT_PATH/requirements.txt" ] || \
   [ -f "$PROJECT_PATH/pyproject.toml" ] || \
   [ -n "$(find "$PROJECT_PATH" -maxdepth 2 -name '*.py' -print -quit 2>/dev/null)" ]; then
    echo "python"
    exit 0
fi

# Detect C/C++ projects via CMakeLists.txt
if [ -f "$PROJECT_PATH/CMakeLists.txt" ]; then
    # Check if CMakeLists.txt mentions CXX (C++) language
    if grep -q "project.*CXX" "$PROJECT_PATH/CMakeLists.txt" 2>/dev/null; then
        echo "cxx"
        exit 0
    else
        echo "c"
        exit 0
    fi
fi

# Unable to detect language
echo "Warning: Could not detect project language" >&2
exit 1
