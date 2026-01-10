#!/usr/bin/env bash
# lol_cmd_serve: Run polling server for GitHub Projects automation

# lol_cmd_serve: Run polling server for GitHub Projects automation
# Runs in subshell to preserve set -e semantics
# Usage: lol_cmd_serve <period> <tg_token> <tg_chat_id> [num_workers]
lol_cmd_serve() (
    set -e

    local period="$1"
    local tg_token="$2"
    local tg_chat_id="$3"
    local num_workers="${4:-5}"

    # Validate required arguments
    if [ -z "$tg_token" ]; then
        echo "Error: --tg-token is required"
        exit 1
    fi

    if [ -z "$tg_chat_id" ]; then
        echo "Error: --tg-chat-id is required"
        exit 1
    fi

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

    # Export TG credentials for spawned sessions
    export AGENTIZE_USE_TG=1
    export TG_API_TOKEN="$tg_token"
    export TG_CHAT_ID="$tg_chat_id"

    # Invoke Python server module
    exec python -m agentize.server --period="$period" --num-workers="$num_workers"
)
