#!/usr/bin/env bash
# lol CLI helper functions
# Provides language detection and other utility functions

# Detect project language based on file structure
# Usage: _lol_detect_lang <project_path>
# Returns: stdout: "python", "c", or "cxx"
#          exit code: 0 if detected, 1 if unable to detect
_lol_detect_lang() {
    local project_path="$1"

    # Validate project path is provided
    if [ -z "$project_path" ]; then
        echo "Error: Project path is required" >&2
        return 1
    fi

    # Detect Python projects
    if [ -f "$project_path/requirements.txt" ] || \
       [ -f "$project_path/pyproject.toml" ] || \
       [ -n "$(find "$project_path" -maxdepth 2 -name '*.py' -print -quit 2>/dev/null)" ]; then
        echo "python"
        return 0
    fi

    # Detect C/C++ projects via CMakeLists.txt
    if [ -f "$project_path/CMakeLists.txt" ]; then
        # Check if CMakeLists.txt mentions CXX (C++) language
        if grep -q "project.*CXX" "$project_path/CMakeLists.txt" 2>/dev/null; then
            echo "cxx"
            return 0
        else
            echo "c"
            return 0
        fi
    fi

    # Unable to detect language
    echo "Warning: Could not detect project language" >&2
    return 1
}
