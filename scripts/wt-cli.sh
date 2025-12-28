#!/usr/bin/env bash
# Per-project wt shell function
# Enables wt init/main/spawn/list/remove/prune from any directory within a git repo

wt() {
    local subcommand="$1"
    shift || true

    # Resolve git repository root
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)

    if [ -z "$repo_root" ]; then
        echo "Error: Not in a git repository"
        echo ""
        echo "The wt command must be run from within a git repository."
        echo "Please navigate to a git repository or run 'git init' to create one."
        return 1
    fi

    # Check if worktree.sh exists in this repo
    if [ ! -f "$repo_root/scripts/worktree.sh" ]; then
        echo "Error: worktree.sh not found at $repo_root/scripts/worktree.sh"
        echo ""
        echo "This repository does not appear to have the worktree management scripts."
        return 1
    fi

    # Save current directory
    local original_dir="$PWD"

    # Handle subcommands
    case "$subcommand" in
        init)
            # Initialize trees/ directory with bare repository pattern
            cd "$repo_root" || {
                echo "Error: Failed to change directory to $repo_root"
                cd "$original_dir"
                return 1
            }

            # Create trees/ directory if it doesn't exist
            if [ ! -d "trees" ]; then
                mkdir -p trees
                echo "Created trees/ directory"
            fi

            # Detect default branch (main or master)
            local default_branch
            default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

            if [ -z "$default_branch" ]; then
                # Fallback: check if trees/main or trees/master exists
                if [ -d "trees/main" ]; then
                    default_branch="main"
                elif [ -d "trees/master" ]; then
                    default_branch="master"
                else
                    # Fallback: check current branch
                    default_branch=$(git branch --show-current)
                fi
            fi

            # Final fallback: check for main or master branch existence
            if [ -z "$default_branch" ]; then
                if git show-ref --verify --quiet refs/heads/main; then
                    default_branch="main"
                elif git show-ref --verify --quiet refs/heads/master; then
                    default_branch="master"
                fi
            fi

            if [ -z "$default_branch" ]; then
                echo "Error: Could not detect default branch"
                cd "$original_dir"
                return 1
            fi

            echo "Detected default branch: $default_branch"

            # Switch main repo to a different branch BEFORE creating worktree
            local current_branch
            current_branch=$(git branch --show-current)

            if [ "$current_branch" = "$default_branch" ]; then
                # Create a detached HEAD state on the current commit
                echo "Switching main repo to detached HEAD to avoid conflicts..."
                git checkout --detach HEAD >/dev/null 2>&1 || {
                    echo "Warning: Failed to switch to detached HEAD, attempting dev branch..."
                    # Try creating a dev branch instead
                    git checkout -b "_worktree_dev" >/dev/null 2>&1 || {
                        echo "Error: Could not switch main repo branch"
                        cd "$original_dir"
                        return 1
                    }
                }
                echo "Main repo switched to avoid conflict"
            fi

            # Check if trees/$default_branch/ already exists
            if [ -d "trees/$default_branch" ]; then
                echo "trees/$default_branch/ worktree already exists"
            else
                # Create trees/main/ (or trees/master/) worktree
                echo "Creating trees/$default_branch/ worktree..."
                git worktree add "trees/$default_branch" "$default_branch" || {
                    echo "Error: Failed to create trees/$default_branch/ worktree"
                    cd "$original_dir"
                    return 1
                }
                echo "Created trees/$default_branch/ worktree"
            fi

            # Update .gitignore to exclude trees/
            if [ -f ".gitignore" ]; then
                # Check if trees/ is already in .gitignore
                if ! grep -q "^trees/$" .gitignore 2>/dev/null; then
                    echo "trees/" >> .gitignore
                    echo "Updated .gitignore to exclude trees/"
                else
                    echo ".gitignore already excludes trees/"
                fi
            else
                echo "trees/" > .gitignore
                echo "Created .gitignore to exclude trees/"
            fi

            echo ""
            echo "Bare repository pattern initialized!"
            echo "- Main worktree: trees/$default_branch/"
            echo "- Use 'wt main' to navigate to trees/$default_branch/"
            echo "- Use 'wt spawn <issue>' to create feature worktrees"

            cd "$original_dir"
            ;;

        main)
            # Navigate to trees/main/ or trees/master/
            cd "$repo_root" || {
                echo "Error: Failed to change directory to $repo_root"
                return 1
            }

            # Check for trees/main/ or trees/master/
            if [ -d "trees/main" ]; then
                cd "trees/main" || {
                    echo "Error: Failed to navigate to trees/main/"
                    cd "$original_dir"
                    return 1
                }
            elif [ -d "trees/master" ]; then
                cd "trees/master" || {
                    echo "Error: Failed to navigate to trees/master/"
                    cd "$original_dir"
                    return 1
                }
            else
                echo "Error: trees/main/ or trees/master/ not found"
                echo ""
                echo "Please run 'wt init' first to initialize the bare repository pattern."
                cd "$original_dir"
                return 1
            fi
            ;;

        spawn)
            # wt spawn <issue-number> [description]
            cd "$repo_root" || {
                echo "Error: Failed to change directory to $repo_root"
                cd "$original_dir"
                return 1
            }

            ./scripts/worktree.sh create "$@"
            local exit_code=$?
            cd "$original_dir"
            return $exit_code
            ;;

        list)
            cd "$repo_root" || {
                echo "Error: Failed to change directory to $repo_root"
                cd "$original_dir"
                return 1
            }

            ./scripts/worktree.sh list
            local exit_code=$?
            cd "$original_dir"
            return $exit_code
            ;;

        remove)
            cd "$repo_root" || {
                echo "Error: Failed to change directory to $repo_root"
                cd "$original_dir"
                return 1
            }

            ./scripts/worktree.sh remove "$@"
            local exit_code=$?
            cd "$original_dir"
            return $exit_code
            ;;

        prune)
            cd "$repo_root" || {
                echo "Error: Failed to change directory to $repo_root"
                cd "$original_dir"
                return 1
            }

            ./scripts/worktree.sh prune
            local exit_code=$?
            cd "$original_dir"
            return $exit_code
            ;;

        *)
            echo "wt: Git worktree helper (per-project)"
            echo ""
            echo "Usage:"
            echo "  wt init                           # Initialize trees/ with bare repository pattern"
            echo "  wt main                           # Navigate to trees/main/ (or trees/master/)"
            echo "  wt spawn <issue-number> [description]"
            echo "  wt list"
            echo "  wt remove <issue-number>"
            echo "  wt prune"
            echo ""
            echo "Examples:"
            echo "  wt init                  # Setup bare repository pattern"
            echo "  wt main                  # Navigate to main worktree"
            echo "  wt spawn 42              # Fetch title from GitHub"
            echo "  wt spawn 42 add-feature  # Use custom description"
            echo "  wt list                  # Show all worktrees"
            echo "  wt remove 42             # Remove worktree for issue 42"
            return 1
            ;;
    esac
}
