#!/usr/bin/env bash
# Cross-project wt shell function
# Enables wt spawn/list/remove/prune from any directory

wt() {
    # Check if AGENTIZE_HOME is set
    if [ -z "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME environment variable is not set"
        echo ""
        echo "Please set AGENTIZE_HOME to point to your agentize repository:"
        echo "  export AGENTIZE_HOME=\"/path/to/agentize\""
        echo "  source \"\$AGENTIZE_HOME/scripts/wt-functions.sh\""
        return 1
    fi

    # Check if AGENTIZE_HOME is a valid directory
    if [ ! -d "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME does not point to a valid directory"
        echo "  Current value: $AGENTIZE_HOME"
        echo ""
        echo "Please set AGENTIZE_HOME to your agentize repository path:"
        echo "  export AGENTIZE_HOME=\"/path/to/agentize\""
        return 1
    fi

    # Check if worktree.sh exists
    if [ ! -f "$AGENTIZE_HOME/scripts/worktree.sh" ]; then
        echo "Error: worktree.sh not found at $AGENTIZE_HOME/scripts/worktree.sh"
        echo "  AGENTIZE_HOME may not point to a valid agentize repository"
        return 1
    fi

    # Save current directory
    local original_dir="$PWD"

    # Change to AGENTIZE_HOME
    cd "$AGENTIZE_HOME" || {
        echo "Error: Failed to change directory to $AGENTIZE_HOME"
        return 1
    }

    # Map wt subcommands to worktree.sh commands
    local subcommand="$1"
    shift || true

    case "$subcommand" in
        spawn)
            # wt spawn <issue-number> [description]
            ./scripts/worktree.sh create "$@"
            ;;
        list)
            ./scripts/worktree.sh list
            ;;
        remove)
            ./scripts/worktree.sh remove "$@"
            ;;
        prune)
            ./scripts/worktree.sh prune
            ;;
        *)
            echo "wt: Git worktree helper (cross-project)"
            echo ""
            echo "Usage:"
            echo "  wt spawn <issue-number> [description]"
            echo "  wt list"
            echo "  wt remove <issue-number>"
            echo "  wt prune"
            echo ""
            echo "Examples:"
            echo "  wt spawn 42              # Fetch title from GitHub"
            echo "  wt spawn 42 add-feature  # Use custom description"
            echo "  wt list                  # Show all worktrees"
            echo "  wt remove 42             # Remove worktree for issue 42"
            cd "$original_dir"
            return 1
            ;;
    esac

    local exit_code=$?

    # Return to original directory
    cd "$original_dir"

    return $exit_code
}
