#!/usr/bin/env bash
# planner: Multi-agent debate pipeline CLI
# This file is sourced by setup.sh and provides all planner functionality
# Source-first implementation following the acw.sh/wt.sh/lol.sh pattern
#
# Module structure:
#   planner/dispatch.sh  - Main dispatcher and help text
#   planner/pipeline.sh  - Multi-agent pipeline orchestration

# Determine script directory for sourcing modules
# Works in both sourced and executed contexts
_planner_script_dir() {
    if [ -n "$BASH_SOURCE" ]; then
        dirname "${BASH_SOURCE[0]}"
    elif [ -n "$ZSH_VERSION" ]; then
        dirname "${(%):-%x}"
    else
        # Fallback for other shells
        dirname "$0"
    fi
}

_PLANNER_DIR="$(_planner_script_dir)"

# Source all modules in dependency order
source "$_PLANNER_DIR/planner/dispatch.sh"
source "$_PLANNER_DIR/planner/pipeline.sh"
