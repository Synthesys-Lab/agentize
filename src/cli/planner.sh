#!/usr/bin/env bash
# planner: Multi-agent debate pipeline library (internal)
# This file provides pipeline functionality used by lol plan
# Source-first implementation following the acw.sh/wt.sh/lol.sh pattern
#
# Module structure:
#   planner/pipeline.sh  - Python backend adapter
#   planner/github.sh    - GitHub issue creation/update helpers

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

# Source shared terminal helpers
source "$_PLANNER_DIR/term/colors.sh"

# Source all modules in dependency order
source "$_PLANNER_DIR/planner/pipeline.sh"
source "$_PLANNER_DIR/planner/github.sh"
