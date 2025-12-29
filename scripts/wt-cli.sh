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
        echo "  source \"\$AGENTIZE_HOME/scripts/wt-cli.sh\""
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
            # wt spawn <issue-number> [description] [--no-agent]
            local no_agent=false
            local args=()

            # Parse arguments and extract --no-agent flag
            for arg in "$@"; do
                if [ "$arg" = "--no-agent" ]; then
                    no_agent=true
                else
                    args+=("$arg")
                fi
            done

            # Create worktree with --print-path to get machine-readable path
            local output
            output=$(./scripts/worktree.sh create --print-path "${args[@]}")
            local create_exit_code=$?

            # Display the worktree creation output
            echo "$output"

            # Check if creation succeeded
            if [ $create_exit_code -ne 0 ]; then
                cd "$original_dir"
                return $create_exit_code
            fi

            # Extract worktree path from marker
            local worktree_path
            worktree_path=$(echo "$output" | grep "^__WT_WORKTREE_PATH__=" | cut -d'=' -f2)

            # Validate path was extracted
            if [ -z "$worktree_path" ]; then
                echo "Warning: Could not extract worktree path"
                cd "$original_dir"
                return 0
            fi

            # Check if path exists
            if [ ! -d "$worktree_path" ]; then
                echo "Warning: Worktree path does not exist: $worktree_path"
                cd "$original_dir"
                return 0
            fi

            # Auto-launch AI agent if interactive and not disabled
            if [ "$no_agent" = false ] && [ -t 0 ]; then
                # Select AI agent command (prefer claude-code, fallback to claude)
                local agent_cmd=""
                if command -v claude-code &> /dev/null; then
                    agent_cmd="claude-code"
                elif command -v claude &> /dev/null; then
                    agent_cmd="claude"
                fi

                if [ -n "$agent_cmd" ]; then
                    echo ""
                    echo "Launching $agent_cmd in $worktree_path..."
                    # Launch agent in subshell rooted at worktree
                    (cd "$AGENTIZE_HOME/$worktree_path" && exec "$agent_cmd")
                else
                    echo ""
                    echo "AI agent not found (tried: claude-code, claude)"
                    echo "Install Claude Code or launch manually:"
                    echo "  cd $AGENTIZE_HOME/$worktree_path"
                    echo "  claude-code"
                fi
            fi
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
            echo "  wt spawn <issue-number> [description] [--no-agent]"
            echo "  wt list"
            echo "  wt remove <issue-number>"
            echo "  wt prune"
            echo ""
            echo "Examples:"
            echo "  wt spawn 42              # Create worktree and auto-launch AI agent"
            echo "  wt spawn 42 --no-agent   # Create worktree without auto-launch"
            echo "  wt spawn 42 add-feature  # Use custom description"
            echo "  wt list                  # Show all worktrees"
            echo "  wt remove 42             # Remove worktree for issue 42"
            echo ""
            echo "Note: Auto-launch only works in interactive shells. Use --no-agent for scripts."
            cd "$original_dir"
            return 1
            ;;
    esac

    local exit_code=$?

    # Return to original directory
    cd "$original_dir"

    return $exit_code
}
