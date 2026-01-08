#!/usr/bin/env bash
# wt: Git worktree helper for bare repositories
# This file is sourced by scripts/wt-cli.sh and provides all wt functionality

# ============================================================================
# SECTION 1: HELPER FUNCTIONS
# ============================================================================

# Get the git common directory (bare repo path) - always returns absolute path
wt_common() {
    local common_dir
    common_dir=$(git rev-parse --git-common-dir 2>/dev/null)

    if [ -z "$common_dir" ]; then
        return 1
    fi

    # Convert to absolute path if relative
    if [[ "$common_dir" != /* ]]; then
        common_dir="$(cd "$common_dir" 2>/dev/null && pwd)"
    fi

    echo "$common_dir"
}

# Check if current repo is a bare repository
wt_is_bare_repo() {
    # Check using git rev-parse --is-bare-repository
    if git rev-parse --is-bare-repository 2>/dev/null | grep -q "true"; then
        return 0
    fi

    # Additional check: if we're in a worktree, check if the common dir is bare
    local common_dir
    common_dir=$(wt_common)

    if [ -n "$common_dir" ] && [ -f "$common_dir/config" ]; then
        if git -C "$common_dir" config --get core.bare 2>/dev/null | grep -q "true"; then
            return 0
        fi
    fi

    return 1
}

# Get the default branch name (WT_DEFAULT_BRANCH or main/master)
wt_get_default_branch() {
    # Use WT_DEFAULT_BRANCH if set
    if [ -n "$WT_DEFAULT_BRANCH" ]; then
        echo "$WT_DEFAULT_BRANCH"
        return 0
    fi

    local common_dir
    common_dir=$(wt_common)

    # For bare repos, check what HEAD points to
    local head_ref
    head_ref=$(git -C "$common_dir" symbolic-ref HEAD 2>/dev/null | sed 's|refs/heads/||')

    if [ -n "$head_ref" ]; then
        echo "$head_ref"
        return 0
    fi

    # Try main first
    if git -C "$common_dir" rev-parse --verify main >/dev/null 2>&1; then
        echo "main"
        return 0
    fi

    # Fallback to master
    if git -C "$common_dir" rev-parse --verify master >/dev/null 2>&1; then
        echo "master"
        return 0
    fi

    # No default branch found
    echo "main"  # Default to main for new repos
    return 0
}

# Resolve worktree path by issue number or name
wt_resolve_worktree() {
    local target="$1"
    local common_dir
    common_dir=$(wt_common)

    if [ -z "$common_dir" ]; then
        return 1
    fi

    local trees_dir="$common_dir/trees"

    # Handle "main" special case
    if [ "$target" = "main" ]; then
        echo "$trees_dir/main"
        return 0
    fi

    # Handle issue number (e.g., "42" -> matches "issue-42" or "issue-42-title")
    if [[ "$target" =~ ^[0-9]+$ ]]; then
        local issue_dir
        # Search only immediate subdirectories of trees/ (maxdepth 1)
        # to avoid matching nested directories or files
        issue_dir=$(find "$trees_dir" -maxdepth 1 -type d -name "issue-$target*" 2>/dev/null | head -1)

        if [ -n "$issue_dir" ]; then
            echo "$issue_dir"
            return 0
        fi
    fi

    return 1
}

# ============================================================================
# SECTION 2: COMMAND IMPLEMENTATIONS
# ============================================================================

# wt common: Print git common directory
cmd_common() {
    wt_common
}

# wt init: Initialize worktree environment
cmd_init() {
    # Check if in a bare repo
    if ! wt_is_bare_repo; then
        echo "Error: wt requires a bare git repository." >&2
        echo "" >&2
        echo "To convert an existing repository to bare:" >&2
        echo "  git clone --bare /path/to/existing/repo /path/to/bare/repo" >&2
        echo "  cd /path/to/bare/repo" >&2
        echo "  wt init" >&2
        return 1
    fi

    local common_dir
    common_dir=$(wt_common)
    local trees_dir="$common_dir/trees"

    # Check if already initialized
    if [ -d "$trees_dir/main" ]; then
        echo "This repository is already initialized."
        return 0
    fi

    # Create trees directory
    mkdir -p "$trees_dir"

    # Get default branch
    local default_branch
    default_branch=$(wt_get_default_branch)

    # Create main worktree
    mkdir -p "$trees_dir"
    git -C "$common_dir" worktree add "$trees_dir/main" "$default_branch" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "Initialized worktree environment: $trees_dir/main"
        return 0
    else
        echo "Error: Failed to create main worktree" >&2
        return 1
    fi
}

# wt goto: Change directory to worktree
cmd_goto() {
    local target="$1"

    if [ -z "$target" ]; then
        echo "Error: Missing target. Usage: wt goto <issue-no>|main" >&2
        return 1
    fi

    local worktree_path
    worktree_path=$(wt_resolve_worktree "$target")

    if [ $? -ne 0 ] || [ -z "$worktree_path" ] || [ ! -d "$worktree_path" ]; then
        echo "Error: Worktree not found for target: $target" >&2
        return 1
    fi

    # Change directory (this only works if wt is sourced, not executed)
    cd "$worktree_path" || return 1

    # Also export for subshells if needed
    export WT_CURRENT_WORKTREE="$worktree_path"

    return 0
}

# wt list: List all worktrees
cmd_list() {
    git worktree list
}

# wt spawn: Create new worktree for issue
cmd_spawn() {
    local issue_no=""
    local no_agent=false
    local yolo=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-agent)
                no_agent=true
                shift
                ;;
            --yolo)
                yolo=true
                shift
                ;;
            -*)
                echo "Error: Unknown flag: $1" >&2
                return 1
                ;;
            *)
                if [ -z "$issue_no" ]; then
                    issue_no="$1"
                else
                    echo "Error: Multiple issue numbers provided" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$issue_no" ]; then
        echo "Error: Missing issue number. Usage: wt spawn <issue-no>" >&2
        return 1
    fi

    # Validate issue number
    if ! [[ "$issue_no" =~ ^[0-9]+$ ]]; then
        echo "Error: Issue number must be numeric" >&2
        return 1
    fi

    # Check if gh is available and validate issue exists
    if command -v gh >/dev/null 2>&1; then
        if ! gh issue view "$issue_no" >/dev/null 2>&1; then
            echo "Error: Issue #$issue_no not found" >&2
            return 1
        fi
    fi

    local common_dir
    common_dir=$(wt_common)

    if [ -z "$common_dir" ]; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi

    local trees_dir="$common_dir/trees"

    # Ensure trees directory exists
    if [ ! -d "$trees_dir" ]; then
        echo "Error: Worktree environment not initialized. Run 'wt init' first." >&2
        return 1
    fi

    # Get default branch
    local default_branch
    default_branch=$(wt_get_default_branch)

    # Create branch name from issue number only
    local branch_name="issue-$issue_no"

    local worktree_path="$trees_dir/$branch_name"

    # Check if worktree already exists
    if [ -d "$worktree_path" ]; then
        echo "Error: Worktree already exists at $worktree_path" >&2
        return 1
    fi

    # Create worktree from default branch
    # In a bare repo, we create worktree directly from the branch ref
    local spawn_error
    spawn_error=$(git -C "$common_dir" worktree add -b "$branch_name" "$worktree_path" "$default_branch" 2>&1)
    local spawn_exit=$?

    if [ $spawn_exit -ne 0 ]; then
        echo "Error: Failed to create worktree for issue #$issue_no" >&2
        echo "  Branch: $branch_name" >&2
        echo "  Path: $worktree_path" >&2
        echo "  Base: $default_branch" >&2
        echo "  Git error: $spawn_error" >&2
        return 1
    fi

    echo "Created worktree: $worktree_path"

    # Add pre-trusted entry to ~/.claude.json to skip trust dialog
    local claude_config="$HOME/.claude.json"
    if [ -f "$claude_config" ] && command -v jq >/dev/null 2>&1; then
        # Check if projects key exists and add the new worktree path
        local tmp_config
        tmp_config=$(mktemp)
        if jq --arg path "$worktree_path" '.projects[$path] = {"allowedTools": [], "hasTrustDialogAccepted": true}' "$claude_config" > "$tmp_config" 2>/dev/null; then
            mv "$tmp_config" "$claude_config"
        else
            rm -f "$tmp_config"
        fi
    fi

    # Invoke Claude if not disabled
    if [ "$no_agent" = false ] && command -v claude >/dev/null 2>&1; then
        local claude_flags=""
        if [ "$yolo" = true ]; then
            echo "WARNING: --yolo active; Claude will run with --dangerously-skip-permissions" >&2
            claude_flags="--dangerously-skip-permissions"
        fi

        echo "Invoking Claude Code..."
        cd "$worktree_path" && claude $claude_flags "/issue-to-impl $issue_no" || {
            echo "Warning: Failed to invoke Claude Code" >&2
        }
    fi

    return 0
}

# wt remove: Remove worktree for issue
cmd_remove() {
    local issue_no=""
    local delete_branch=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --delete-branch|-D|--force)
                delete_branch=true
                shift
                ;;
            -*)
                echo "Error: Unknown flag: $1" >&2
                return 1
                ;;
            *)
                if [ -z "$issue_no" ]; then
                    issue_no="$1"
                else
                    echo "Error: Multiple issue numbers provided" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$issue_no" ]; then
        echo "Error: Missing issue number. Usage: wt remove <issue-no>" >&2
        return 1
    fi

    local worktree_path
    worktree_path=$(wt_resolve_worktree "$issue_no")

    if [ $? -ne 0 ] || [ -z "$worktree_path" ] || [ ! -d "$worktree_path" ]; then
        echo "Error: Worktree not found for issue: $issue_no" >&2
        return 1
    fi

    # Get branch name
    local branch_name
    branch_name=$(basename "$worktree_path")

    # Remove worktree
    git worktree remove "$worktree_path"

    if [ $? -eq 0 ]; then
        echo "Removed worktree: $worktree_path"

        # Delete branch if requested
        if [ "$delete_branch" = true ]; then
            git branch -D "$branch_name"
            if [ $? -eq 0 ]; then
                echo "Deleted branch: $branch_name"
            fi
        fi

        return 0
    else
        echo "Error: Failed to remove worktree" >&2
        return 1
    fi
}

# wt prune: Clean up stale worktree metadata
cmd_prune() {
    git worktree prune
}

# wt purge: Remove worktrees for closed issues
cmd_purge() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: gh CLI is required for purge command" >&2
        return 1
    fi

    local common_dir
    common_dir=$(wt_common)

    if [ -z "$common_dir" ]; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi

    local trees_dir="$common_dir/trees"

    if [ ! -d "$trees_dir" ]; then
        echo "No worktrees to purge."
        return 0
    fi

    # Find all issue worktrees
    local purged_count=0

    for worktree_dir in "$trees_dir"/issue-*; do
        if [ ! -d "$worktree_dir" ]; then
            continue
        fi

        local branch_name
        branch_name=$(basename "$worktree_dir")

        # Extract issue number from branch name (issue-42-* -> 42)
        local issue_no
        issue_no=$(echo "$branch_name" | sed 's/^issue-//' | sed 's/-.*//')

        if [ -z "$issue_no" ]; then
            continue
        fi

        # Check if issue is closed
        local issue_state
        issue_state=$(gh issue view "$issue_no" --json state --jq '.state' 2>/dev/null)

        if [ "$issue_state" = "CLOSED" ]; then
            echo "Removing closed issue worktree: $branch_name"

            # Remove worktree
            git worktree remove "$worktree_dir" 2>/dev/null

            # Remove branch
            git branch -D "$branch_name" 2>/dev/null

            echo "Branch and worktree of $branch_name removed."
            purged_count=$((purged_count + 1))
        fi
    done

    if [ $purged_count -eq 0 ]; then
        echo "No closed issue worktrees found."
    else
        echo "Purged $purged_count worktree(s)."
    fi

    return 0
}

# wt help: Show help message
cmd_help() {
    cat <<'EOF'
wt: Git worktree helper for bare repositories

USAGE:
  wt <command> [options]

COMMANDS:
  common              Print the git common directory (bare repo path)
  init                Initialize worktree environment (run once per repo)
  goto <target>       Change directory to worktree (target: main or issue-no)
  spawn <issue-no>    Create new worktree for issue (from default branch)
  list                List all worktrees
  remove <issue-no>   Remove worktree for issue
  prune               Clean up stale worktree metadata
  purge               Remove worktrees for closed GitHub issues
  help                Show this help message

OPTIONS (spawn):
  --no-agent          Skip automatic Claude invocation
  --yolo              Skip permission prompts

OPTIONS (remove):
  --delete-branch     Delete branch even if unmerged
  -D, --force         Alias for --delete-branch

REQUIREMENTS:
  - Bare git repository (create with: git clone --bare)
  - gh CLI (for spawn validation and purge)

EXAMPLES:
  wt init                    # Initialize worktree environment
  wt goto main               # Go to main worktree
  wt spawn 42                # Create worktree for issue #42
  wt goto 42                 # Go to issue #42 worktree
  wt remove 42 --delete-branch   # Remove issue #42 worktree and branch
  wt purge                   # Remove all closed issue worktrees

For detailed documentation, see: docs/cli/wt.md
EOF
}

# ============================================================================
# SECTION 3: MAIN DISPATCHER
# ============================================================================

# Main wt function
wt() {
    local command="$1"
    [ $# -gt 0 ] && shift

    case "$command" in
        common)
            cmd_common "$@"
            ;;
        init)
            cmd_init "$@"
            ;;
        goto)
            cmd_goto "$@"
            ;;
        spawn)
            cmd_spawn "$@"
            ;;
        remove)
            cmd_remove "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        prune)
            cmd_prune "$@"
            ;;
        purge)
            cmd_purge "$@"
            ;;
        help|--help|-h|"")
            cmd_help
            ;;
        --complete)
            # Completion helper (to be implemented)
            local topic="$1"
            case "$topic" in
                commands)
                    echo "common"
                    echo "init"
                    echo "goto"
                    echo "spawn"
                    echo "list"
                    echo "remove"
                    echo "prune"
                    echo "purge"
                    echo "help"
                    ;;
                spawn-flags)
                    echo "--yolo"
                    echo "--no-agent"
                    ;;
                remove-flags)
                    echo "--delete-branch"
                    echo "-D"
                    echo "--force"
                    ;;
                goto-targets)
                    # List available worktrees
                    local common_dir
                    common_dir=$(wt_common 2>/dev/null)
                    if [ -n "$common_dir" ] && [ -d "$common_dir/trees" ]; then
                        echo "main"
                        find "$common_dir/trees" -maxdepth 1 -type d -name "issue-*" 2>/dev/null | \
                            xargs -n1 basename 2>/dev/null | \
                            sed 's/^issue-//' | \
                            sed 's/-.*$//'
                    fi
                    ;;
            esac
            ;;
        *)
            echo "Error: Unknown command: $command" >&2
            echo "Run 'wt help' for usage information" >&2
            return 1
            ;;
    esac
}
