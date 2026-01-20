#!/usr/bin/env bash
# acw: Agent CLI Wrapper
# This file is sourced by setup.sh and provides all acw functionality
# Source-first implementation following the wt.sh/lol.sh pattern
#
# Module structure:
#   acw/helpers.sh   - Validation and utility functions
#   acw/providers.sh - Provider-specific invocation functions
#   acw/dispatch.sh  - Main dispatcher and help text

# Determine script directory for sourcing modules
# Works in both sourced and executed contexts
_acw_script_dir() {
    if [ -n "$BASH_SOURCE" ]; then
        dirname "${BASH_SOURCE[0]}"
    elif [ -n "$ZSH_VERSION" ]; then
        dirname "${(%):-%x}"
    else
        # Fallback for other shells
        dirname "$0"
    fi
}

_ACW_DIR="$(_acw_script_dir)"

# Source all modules in dependency order
source "$_ACW_DIR/acw/helpers.sh"
source "$_ACW_DIR/acw/providers.sh"
source "$_ACW_DIR/acw/dispatch.sh"
