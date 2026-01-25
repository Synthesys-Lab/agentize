#!/usr/bin/env bash

# lol_cmd_serve: Run polling server for GitHub Projects automation
# Runs in subshell to preserve set -e semantics
# Usage: lol_cmd_serve <period> [num_workers]
# TG credentials are YAML-only (loaded from .agentize.local.yaml in Python)
lol_cmd_serve() (
    set -e

    local period="$1"
    local num_workers="${2:-5}"

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

    # TG credentials are YAML-only - loaded from .agentize.local.yaml in Python
    # No environment variable exports needed

    # Invoke Python server module
    exec python -m agentize.server --period="$period" --num-workers="$num_workers"
)
