#!/usr/bin/env bash
# wt: Git worktree helper for bare repositories
# This file is sourced by setup.sh and provides all wt functionality
# Source-first implementation following the lol.sh pattern
#
# Module structure:
#   wt/helpers.sh    - Repository detection, path resolution, and project status helpers
#   wt/completion.sh - Shell-agnostic completion helper
#   wt/commands.sh   - Command implementations (cmd_*)
#   wt/dispatch.sh   - Main dispatcher and entry point

# Determine script directory for sourcing modules
# Works in both sourced and executed contexts
_wt_script_dir() {
    if [ -n "$BASH_SOURCE" ]; then
        dirname "${BASH_SOURCE[0]}"
    elif [ -n "$ZSH_VERSION" ]; then
        dirname "${(%):-%x}"
    else
        # Fallback for other shells
        dirname "$0"
    fi
}

_WT_DIR="$(_wt_script_dir)"

# Source all modules in dependency order
source "$_WT_DIR/wt/helpers.sh"
source "$_WT_DIR/wt/completion.sh"
source "$_WT_DIR/wt/commands.sh"
source "$_WT_DIR/wt/dispatch.sh"
