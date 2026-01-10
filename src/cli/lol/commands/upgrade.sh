#!/usr/bin/env bash
# lol_cmd_upgrade: Upgrade agentize installation

# lol_cmd_upgrade: Upgrade agentize installation
# Runs in subshell to preserve set -e semantics
lol_cmd_upgrade() (
    set -e

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

    # Resolve default branch from origin/HEAD, fallback to main
    local default_branch
    default_branch=$(git -C "$AGENTIZE_HOME" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -z "$default_branch" ]; then
        echo "Note: origin/HEAD not set, using 'main' as default branch"
        default_branch="main"
    fi

    echo "Upgrading agentize installation..."
    echo "  AGENTIZE_HOME: $AGENTIZE_HOME"
    echo "  Default branch: $default_branch"
    echo ""

    # Run git pull --rebase
    if git -C "$AGENTIZE_HOME" pull --rebase origin "$default_branch"; then
        echo ""
        echo "Upgrade successful!"
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
