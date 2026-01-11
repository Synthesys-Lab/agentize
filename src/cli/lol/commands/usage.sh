#!/usr/bin/env bash
# lol usage command implementation
# Shell wrapper that invokes Python usage module

# Report Claude Code token usage statistics
# Usage: lol_cmd_usage [mode]
#   mode: "today" (default) or "week"
lol_cmd_usage() {
    local mode="${1:-today}"

    # Invoke Python usage module with appropriate flag
    if [ "$mode" = "week" ]; then
        python3 -m agentize.usage --week
    else
        python3 -m agentize.usage --today
    fi
}
