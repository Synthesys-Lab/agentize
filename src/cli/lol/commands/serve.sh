#!/usr/bin/env bash

# lol_cmd_serve: Run polling server for GitHub Projects automation
# Runs in subshell to preserve set -e semantics
# Usage: lol_cmd_serve <period> [tg_token] [tg_chat_id] [num_workers]
lol_cmd_serve() (
    set -e

    local period="$1"
    local tg_token="$2"
    local tg_chat_id="$3"
    local num_workers="${4:-5}"

    # Check if in a bare repo with wt initialized
    if ! wt_is_bare_repo 2>/dev/null; then
        echo "Error: lol serve requires a bare git repository"
        echo ""
        echo "Please run from a bare repository with wt init completed."
        exit 1
    fi

    # Check if gh is authenticated
    if ! gh auth status &>/dev/null; then
        echo "Error: GitHub CLI is not authenticated"
        echo ""
        echo "Please authenticate: gh auth login"
        exit 1
    fi

    # Conditionally export TG credentials for spawned sessions
    # Empty exports would override YAML config, so only export when provided
    if [ -n "$tg_token" ]; then
        export TG_API_TOKEN="$tg_token"
    fi
    if [ -n "$tg_chat_id" ]; then
        export TG_CHAT_ID="$tg_chat_id"
    fi
    if [ -n "$tg_token" ] && [ -n "$tg_chat_id" ]; then
        export AGENTIZE_USE_TG=1
    fi

    # Invoke Python server module
    exec python -m agentize.server --period="$period" --num-workers="$num_workers"
)
