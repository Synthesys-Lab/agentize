#!/usr/bin/env bash
# lol simp command implementation
# Delegates to the Python simplifier workflow

# Main _lol_cmd_simp function
# Arguments:
#   $1 - file_path: Optional file path to simplify
#   $2 - issue_number: Optional issue number to publish the report
#   $3 - focus: Optional focus description to guide simplification
_lol_cmd_simp() {
    local file_path="$1"
    local issue_number="$2"
    local focus="$3"

    # Build command arguments
    local cmd_args=()

    if [ -n "$file_path" ]; then
        cmd_args+=("$file_path")
    fi

    if [ -n "$focus" ]; then
        cmd_args+=("--focus" "$focus")
    fi

    if [ -n "$issue_number" ]; then
        cmd_args+=("--issue" "$issue_number")
    fi

    python -m agentize.cli simp "${cmd_args[@]}"
}
