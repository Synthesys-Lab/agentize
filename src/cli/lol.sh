#!/usr/bin/env bash
# lol: AI-powered SDK CLI
# This file is sourced by setup.sh and provides all lol functionality
# Source-first implementation following the wt.sh pattern
#
# Module structure:
#   lol/helpers.sh    - Language detection and utility functions
#   lol/completion.sh - Shell-agnostic completion helper
#   lol/commands.sh   - Thin loader that sources commands/*.sh
#   lol/commands/     - Per-command implementations (lol_cmd_*)
#   lol/parsers.sh    - Argument parsing for each command
#   lol/dispatch.sh   - Main dispatcher and help text

# Determine script directory for sourcing modules
# Works in both sourced and executed contexts
_lol_script_dir() {
    if [ -n "$BASH_SOURCE" ]; then
        dirname "${BASH_SOURCE[0]}"
    elif [ -n "$ZSH_VERSION" ]; then
        dirname "${(%):-%x}"
    else
        # Fallback for other shells
        dirname "$0"
    fi
}

_LOL_DIR="$(_lol_script_dir)"

# Source all modules in dependency order
source "$_LOL_DIR/lol/helpers.sh"
source "$_LOL_DIR/lol/completion.sh"
source "$_LOL_DIR/lol/commands.sh"
source "$_LOL_DIR/lol/parsers.sh"
source "$_LOL_DIR/lol/dispatch.sh"
