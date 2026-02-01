#!/usr/bin/env bash

# _lol_cmd_upgrade: Upgrade agentize installation
# Runs in subshell to preserve set -e semantics
_lol_cmd_upgrade() (
    set -e

    local keep_branch="${1:-0}"

    # Validate AGENTIZE_HOME is a valid git worktree
    if ! git -C "$AGENTIZE_HOME" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: AGENTIZE_HOME is not a valid git worktree."
        echo "  Current value: $AGENTIZE_HOME"
        exit 1
    fi

    # Check for uncommitted changes (dirty-tree guard)
    if [ -n "$(git -C "$AGENTIZE_HOME" status --porcelain)" ]; then
        echo "Warning: Uncommitted changes detected in AGENTIZE_HOME."
        echo ""
        echo "Please commit or stash your changes before upgrading:"
        echo "  git add ."
        echo "  git commit -m \"...\""
        echo "OR"
        echo "  git stash"
        exit 1
    fi

    local current_branch
    current_branch=$(git -C "$AGENTIZE_HOME" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    # Resolve default branch from origin/HEAD, fallback to main
    local default_branch
    default_branch=$(git -C "$AGENTIZE_HOME" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -z "$default_branch" ]; then
        echo "Note: origin/HEAD not set, using 'main' as default branch"
        default_branch="main"
    fi

    local pull_remote="origin"
    local pull_branch="$default_branch"

    if [ "$keep_branch" = "1" ]; then
        if [ -z "$current_branch" ] || [ "$current_branch" = "HEAD" ]; then
            echo "Error: Cannot keep branch when HEAD is detached."
            echo "Run without --keep-branch to upgrade the default branch."
            exit 1
        fi

        local upstream
        if ! upstream=$(git -C "$AGENTIZE_HOME" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null); then
            echo "Error: Current branch has no upstream configured."
            echo "Set an upstream with:"
            echo "  git -C \"\$AGENTIZE_HOME\" branch --set-upstream-to origin/<branch>"
            echo "OR rerun without --keep-branch to upgrade the default branch."
            exit 1
        fi

        pull_remote="${upstream%%/*}"
        pull_branch="${upstream#*/}"
    else
        if [ "$current_branch" != "$default_branch" ]; then
            echo "Switching to default branch: $default_branch"
            if ! git -C "$AGENTIZE_HOME" checkout "$default_branch" >/dev/null 2>&1; then
                echo "Default branch '$default_branch' not found locally; creating from origin/$default_branch"
                if ! git -C "$AGENTIZE_HOME" fetch origin "$default_branch"; then
                    echo "Error: Failed to fetch origin/$default_branch"
                    exit 1
                fi
                git -C "$AGENTIZE_HOME" checkout -b "$default_branch" --track "origin/$default_branch"
            fi
            current_branch="$default_branch"
        fi
    fi

    echo "Upgrading agentize installation..."
    echo "  AGENTIZE_HOME: $AGENTIZE_HOME"
    echo "  Default branch: $default_branch"
    echo "  Current branch: $current_branch"
    if [ "$keep_branch" = "1" ]; then
        echo "  Upgrade branch: $current_branch (keeping current branch)"
        echo "  Upstream: $pull_remote/$pull_branch"
    else
        echo "  Upgrade branch: $default_branch (default branch)"
    fi
    echo ""

    # Run git pull --rebase
    if git -C "$AGENTIZE_HOME" pull --rebase "$pull_remote" "$pull_branch"; then
        echo ""
        echo "Running make setup to rebuild environment configuration..."
        if ! make -C "$AGENTIZE_HOME" setup; then
            echo ""
            echo "Error: make setup failed after pull"
            exit 1
        fi
        # Optional: update Claude plugin if claude is available
        if command -v claude >/dev/null 2>&1; then
            echo "Updating Claude plugin..."
            claude plugin marketplace update agentize >/dev/null 2>&1 || true
            claude plugin update agentize@agentize >/dev/null 2>&1 || true
        fi
        echo ""
        echo "Upgrade successful! (pulled updates and rebuilt setup.sh)"
        echo ""
        echo "To apply changes, reload your shell:"
        echo "  exec \$SHELL                # Clean shell restart (recommended)"
        echo "OR"
        echo "  source \"\$AGENTIZE_HOME/setup.sh\"  # In-place reload"
        exit 0
    else
        echo ""
        echo "Error: git pull --rebase failed."
        echo ""
        echo "To resolve:"
        echo "1. Fix conflicts in the files listed above"
        echo "2. Stage resolved files: git add <file>"
        echo "3. Continue: git -C \$AGENTIZE_HOME rebase --continue"
        echo "OR abort: git -C \$AGENTIZE_HOME rebase --abort"
        echo ""
        echo "Then retry: lol upgrade"
        exit 1
    fi
)
