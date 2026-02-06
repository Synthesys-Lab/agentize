#!/usr/bin/env bash
# lol simp command implementation
# Delegates to the Python simplifier workflow

# Main _lol_cmd_simp function
# Arguments:
#   $1 - file_path: Optional file path to simplify
#   $2 - issue_number: Optional issue number to publish the report
_lol_cmd_simp() {
    local file_path="$1"
    local issue_number="$2"

    if [ -n "$issue_number" ] && [ -n "$file_path" ]; then
        python -m agentize.cli simp "$file_path" --issue "$issue_number"
    elif [ -n "$issue_number" ]; then
        python -m agentize.cli simp --issue "$issue_number"
    elif [ -n "$file_path" ]; then
        python -m agentize.cli simp "$file_path"
    else
        python -m agentize.cli simp
    fi
}
