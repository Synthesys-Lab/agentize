#!/usr/bin/env bash

# _lol_cmd_use_branch: Switch to a remote development branch
# Runs in subshell to preserve set -e semantics
_lol_cmd_use_branch() (
    set -e

    local remote="$1"
    local branch="$2"

    if [ -z "$remote" ] || [ -z "$branch" ]; then
        echo "Error: Missing branch reference."
        echo "Usage: lol use-branch <remote>/<branch>"
        echo "       lol use-branch <branch>"
        exit 1
    fi

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
        echo "Please commit or stash your changes before switching branches:"
        echo "  git add ."
        echo "  git commit -m \"...\""
        echo "OR"
        echo "  git stash"
        exit 1
    fi

    # Validate remote exists
    if ! git -C "$AGENTIZE_HOME" remote get-url "$remote" >/dev/null 2>&1; then
        echo "Error: Remote '$remote' is not configured in AGENTIZE_HOME."
        echo ""
        echo "Available remotes:"
        git -C "$AGENTIZE_HOME" remote -v | awk '{print "  " $1}' | sort -u
        exit 1
    fi

    echo "Switching agentize branch..."
    echo "  AGENTIZE_HOME: $AGENTIZE_HOME"
    echo "  Remote branch: $remote/$branch"
    echo ""

    echo "Fetching $remote/$branch..."
    if ! git -C "$AGENTIZE_HOME" fetch "$remote" "$branch"; then
        echo ""
        echo "Error: Failed to fetch $remote/$branch."
        exit 1
    fi

    if ! git -C "$AGENTIZE_HOME" show-ref --verify --quiet "refs/remotes/$remote/$branch"; then
        echo ""
        echo "Error: Remote branch '$remote/$branch' not found."
        exit 1
    fi

    if git -C "$AGENTIZE_HOME" show-ref --verify --quiet "refs/heads/$branch"; then
        echo "Checking out existing branch '$branch'..."
        git -C "$AGENTIZE_HOME" checkout "$branch"
    else
        echo "Creating tracking branch '$branch' from $remote/$branch..."
        git -C "$AGENTIZE_HOME" checkout -b "$branch" --track "$remote/$branch"
    fi

    if ! git -C "$AGENTIZE_HOME" rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
        echo "Setting upstream for '$branch' to $remote/$branch..."
        git -C "$AGENTIZE_HOME" branch --set-upstream-to "$remote/$branch" "$branch"
    fi

    echo ""
    echo "Running make setup to rebuild environment configuration..."
    if ! make -C "$AGENTIZE_HOME" setup; then
        echo ""
        echo "Error: make setup failed after branch switch"
        exit 1
    fi

    echo ""
    echo "Branch switch complete."
    echo ""
    echo "To apply changes, reload your shell:"
    echo "  exec \$SHELL                # Clean shell restart (recommended)"
    echo "OR"
    echo "  source \"\$AGENTIZE_HOME/setup.sh\"  # In-place reload"
)
