#!/usr/bin/env bash
# lol rebase command implementation
# Delegates to the Python CLI rebase handler

# Main _lol_cmd_rebase function
# Arguments:
#   $1 - target_branch: Target branch to rebase onto (optional, auto-detects main/master)
_lol_cmd_rebase() {
    local target_branch="$1"

    if [ -n "$target_branch" ]; then
        python -m agentize.cli rebase --target-branch "$target_branch"
    else
        python -m agentize.cli rebase
    fi
}
