#!/usr/bin/env bash
# Worktree management CLI and library
# Can be executed directly or sourced for function access

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Max suffix length (configurable via env var)
SUFFIX_MAX_LENGTH="${WORKTREE_SUFFIX_MAX_LENGTH:-10}"

# Resolve the main repository root from git common dir
# This works even when called from a linked worktree
wt_resolve_repo_root() {
    local git_common_dir
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)

    if [ -z "$git_common_dir" ]; then
        echo -e "${RED}Error: Not in a git repository${NC}" >&2
        return 1
    fi

    # Convert to absolute path
    if [ "$git_common_dir" = ".git" ]; then
        # We're in the main repo
        pwd
    else
        # We're in a linked worktree, resolve to absolute path
        cd "$git_common_dir/.." && pwd
    fi
}

# Helper function to convert title to branch-safe format
slugify() {
    local input="$1"
    # Remove tag prefixes like [plan][feat]: from issue titles
    input=$(echo "$input" | sed 's/\[[^]]*\]//g' | sed 's/^[[:space:]]*://' | sed 's/^[[:space:]]*//')
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    echo "$input" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Truncate suffix to max length, preferring word boundaries
truncate_suffix() {
    local suffix="$1"
    local max_len="$SUFFIX_MAX_LENGTH"

    # If already short enough, return as-is
    if [ ${#suffix} -le "$max_len" ]; then
        echo "$suffix"
        return
    fi

    # Try to find last hyphen within limit
    local truncated="${suffix:0:$max_len}"
    local last_hyphen="${truncated%-*}"

    # If we found a hyphen and it's not empty, use word boundary
    if [ -n "$last_hyphen" ] && [ "$last_hyphen" != "$truncated" ]; then
        echo "$last_hyphen"
    else
        # Otherwise, hard truncate
        echo "$truncated"
    fi
}

# Create worktree
cmd_create() {
    local issue_number="$1"
    local description="$2"

    if [ -z "$issue_number" ]; then
        echo -e "${RED}Error: Issue number required${NC}"
        echo "Usage: cmd_create <issue-number> [description]"
        return 1
    fi

    # Resolve repo root
    local repo_root
    repo_root=$(wt_resolve_repo_root)
    if [ $? -ne 0 ]; then
        return 1
    fi

    # If no description provided, fetch from GitHub
    if [ -z "$description" ]; then
        echo "Fetching issue title from GitHub..."
        if ! command -v gh &> /dev/null; then
            echo -e "${RED}Error: gh CLI not found. Install it or provide a description${NC}"
            echo "Usage: cmd_create <issue-number> <description>"
            return 1
        fi

        local issue_title
        issue_title=$(gh issue view "$issue_number" --json title --jq '.title' 2>/dev/null)

        if [ -z "$issue_title" ]; then
            echo -e "${RED}Error: Could not fetch issue #${issue_number}${NC}"
            echo "Provide a description manually: cmd_create $issue_number <description>"
            return 1
        fi

        description=$(slugify "$issue_title")
        echo "Using title: $issue_title"
    fi

    # Apply suffix truncation
    description=$(truncate_suffix "$description")

    local branch_name="issue-${issue_number}-${description}"
    local worktree_path="$repo_root/trees/${branch_name}"

    # Check if worktree already exists
    if [ -d "$worktree_path" ]; then
        echo -e "${YELLOW}Warning: Worktree already exists at ${worktree_path}${NC}"
        return 1
    fi

    # Detect main branch (main or master)
    local main_branch
    if git -C "$repo_root" show-ref --verify --quiet refs/heads/main; then
        main_branch="main"
    elif git -C "$repo_root" show-ref --verify --quiet refs/heads/master; then
        main_branch="master"
    else
        echo -e "${RED}Error: Cannot find main or master branch${NC}"
        return 1
    fi

    echo "Updating $main_branch branch..."

    # Checkout main branch in main repo
    git -C "$repo_root" checkout "$main_branch" || {
        echo -e "${RED}Error: Failed to checkout $main_branch${NC}"
        return 1
    }

    # Pull latest changes from origin with rebase
    git -C "$repo_root" pull origin "$main_branch" --rebase || {
        echo -e "${YELLOW}Warning: Failed to pull from origin/$main_branch${NC}"
        echo "Continuing with local $main_branch..."
    }

    echo "Creating worktree: $worktree_path"
    echo "Branch: $branch_name (forked from $main_branch)"

    # Create worktree from main branch using git -C to operate on main repo
    git -C "$repo_root" worktree add -b "$branch_name" "$worktree_path" "$main_branch"

    # Bootstrap CLAUDE.md if it exists in main repo
    if [ -f "$repo_root/CLAUDE.md" ]; then
        cp "$repo_root/CLAUDE.md" "$worktree_path/CLAUDE.md"
        echo "Bootstrapped CLAUDE.md"
    fi

    echo -e "${GREEN}✓ Worktree created successfully${NC}"
    echo ""
    echo "To start working:"
    echo "  cd $worktree_path"
    echo "  claude-code"
}

# List worktrees
cmd_list() {
    # Resolve repo root
    local repo_root
    repo_root=$(wt_resolve_repo_root)
    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "Active worktrees:"
    git -C "$repo_root" worktree list
}

# Remove worktree
cmd_remove() {
    local issue_number="$1"

    if [ -z "$issue_number" ]; then
        echo -e "${RED}Error: Issue number required${NC}"
        echo "Usage: cmd_remove <issue-number>"
        return 1
    fi

    # Resolve repo root
    local repo_root
    repo_root=$(wt_resolve_repo_root)
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Find worktree matching issue number
    local worktree_path
    worktree_path=$(git -C "$repo_root" worktree list --porcelain | grep "^worktree " | cut -d' ' -f2 | grep "trees/issue-${issue_number}-" | head -n1)

    if [ -z "$worktree_path" ]; then
        echo -e "${YELLOW}Warning: No worktree found for issue #${issue_number}${NC}"
        return 1
    fi

    echo "Removing worktree: $worktree_path"

    # Remove worktree (force to handle untracked/uncommitted files)
    git -C "$repo_root" worktree remove --force "$worktree_path"

    echo -e "${GREEN}✓ Worktree removed successfully${NC}"
}

# Prune stale worktree metadata
cmd_prune() {
    # Resolve repo root
    local repo_root
    repo_root=$(wt_resolve_repo_root)
    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "Pruning stale worktree metadata..."
    git -C "$repo_root" worktree prune
    echo -e "${GREEN}✓ Prune completed${NC}"
}

# Cross-project wt shell function
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

    # Save current directory
    local original_dir="$PWD"

    # Change to AGENTIZE_HOME
    cd "$AGENTIZE_HOME" || {
        echo "Error: Failed to change directory to $AGENTIZE_HOME"
        return 1
    }

    # Map wt subcommands to cmd_* functions
    local subcommand="$1"
    shift || true

    case "$subcommand" in
        spawn)
            # wt spawn <issue-number> [description]
            cmd_create "$@"
            ;;
        list)
            cmd_list
            ;;
        remove)
            cmd_remove "$@"
            ;;
        prune)
            cmd_prune
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

# CLI main function for wrapper script
wt_cli_main() {
    # Resolve repo root first
    local repo_root
    repo_root=$(wt_resolve_repo_root)
    if [ $? -ne 0 ]; then
        return 1
    fi

    local cmd="$1"
    shift || true

    case "$cmd" in
        create)
            cmd_create "$@"
            ;;
        list)
            cmd_list
            ;;
        remove)
            cmd_remove "$@"
            ;;
        prune)
            cmd_prune
            ;;
        *)
            echo "Git Worktree Helper"
            echo ""
            echo "Usage:"
            echo "  $(basename "$0") create <issue-number> [description]"
            echo "  $(basename "$0") list"
            echo "  $(basename "$0") remove <issue-number>"
            echo "  $(basename "$0") prune"
            echo ""
            echo "Examples:"
            echo "  $(basename "$0") create 42              # Fetch title from GitHub"
            echo "  $(basename "$0") create 42 add-feature  # Use custom description"
            echo "  $(basename "$0") list                   # Show all worktrees"
            echo "  $(basename "$0") remove 42              # Remove worktree for issue 42"
            return 1
            ;;
    esac
}

# If script is executed (not sourced), run the CLI main function
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    wt_cli_main "$@"
    exit $?
fi
