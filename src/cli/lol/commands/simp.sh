#!/usr/bin/env bash
# lol simp command implementation
# Delegates to the Python simplifier workflow

# Main _lol_cmd_simp function
# Arguments:
#   $1 - file_path: Optional file path to simplify
_lol_cmd_simp() {
    local file_path="$1"

    if [ -n "$file_path" ]; then
        python -m agentize.cli simp "$file_path"
    else
        python -m agentize.cli simp
    fi
}
