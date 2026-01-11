#!/usr/bin/env bash
# lol usage command implementation
# Shell wrapper that invokes Python usage module

# Report Claude Code token usage statistics
# Usage: lol_cmd_usage [mode] [cache] [cost]
#   mode: "today" (default) or "week"
#   cache: "1" to show cache tokens, "0" to hide (default)
#   cost: "1" to show cost estimate, "0" to hide (default)
lol_cmd_usage() {
    local mode="${1:-today}"
    local cache="${2:-0}"
    local cost="${3:-0}"

    # Build command arguments
    local args=()
    if [ "$mode" = "week" ]; then
        args+=(--week)
    else
        args+=(--today)
    fi
    if [ "$cache" = "1" ]; then
        args+=(--cache)
    fi
    if [ "$cost" = "1" ]; then
        args+=(--cost)
    fi

    # Invoke Python usage module
    python3 -m agentize.usage "${args[@]}"
}
