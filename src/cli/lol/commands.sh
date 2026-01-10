#!/usr/bin/env bash
# lol CLI command implementations (split into commands/)
# This file sources per-command files from commands/ directory

_lol_commands_dir() {
    if [ -n "$BASH_SOURCE" ]; then
        dirname "${BASH_SOURCE[0]}"
    elif [ -n "$ZSH_VERSION" ]; then
        dirname "${(%):-%x}"
    else
        dirname "$0"
    fi
}

_LOL_COMMANDS_DIR="$(_lol_commands_dir)"

source "$_LOL_COMMANDS_DIR/commands/init.sh"
source "$_LOL_COMMANDS_DIR/commands/update.sh"
source "$_LOL_COMMANDS_DIR/commands/upgrade.sh"
source "$_LOL_COMMANDS_DIR/commands/version.sh"
source "$_LOL_COMMANDS_DIR/commands/project.sh"
source "$_LOL_COMMANDS_DIR/commands/serve.sh"
source "$_LOL_COMMANDS_DIR/commands/claude-clean.sh"
