#!/usr/bin/env bash
# Git worktree helper script for parallel agent development
# Creates, lists, and removes worktrees following issue-<N>-<title> convention

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if [ ! -d ".git" ] && [ ! -f ".git" ]; then
    echo -e "${RED}Error: Not in a git repository root${NC}"
    exit 1
fi

# Refuse to run from a linked worktree
if [ -f ".git" ]; then
    echo -e "${RED}Error: Cannot run from a linked worktree${NC}"
    echo "Please run this script from the main repository root"
    exit 1
fi

# Max suffix length (configurable via env var)
SUFFIX_MAX_LENGTH="${WORKTREE_SUFFIX_MAX_LENGTH:-10}"

# Helper function to convert title to branch-safe format
slugify() {
    local input="$1"
    # Remove tag prefixes like [plan][feat]: from issue titles
    # Pattern: \[[^]]*\] matches [anything] including multiple tags
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
    local issue_number=""
    local description=""
    local print_path=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --print-path)
                print_path=true
                shift
                ;;
            *)
                if [ -z "$issue_number" ]; then
                    issue_number="$1"
                elif [ -z "$description" ]; then
                    description="$1"
                fi
                shift
                ;;
        esac
    done

    if [ -z "$issue_number" ]; then
        echo -e "${RED}Error: Issue number required${NC}"
        echo "Usage: $0 create <issue-number> [description] [--print-path]"
        exit 1
    fi

    # If no description provided, fetch from GitHub
    if [ -z "$description" ]; then
        echo "Fetching issue title from GitHub..."
        if ! command -v gh &> /dev/null; then
            echo -e "${RED}Error: gh CLI not found. Install it or provide a description${NC}"
            echo "Usage: $0 create <issue-number> <description>"
            exit 1
        fi

        local issue_title
        issue_title=$(gh issue view "$issue_number" --json title --jq '.title' 2>/dev/null)

        if [ -z "$issue_title" ]; then
            echo -e "${RED}Error: Could not fetch issue #${issue_number}${NC}"
            echo "Provide a description manually: $0 create $issue_number <description>"
            exit 1
        fi

        description=$(slugify "$issue_title")
        echo "Using title: $issue_title"
    fi

    # Apply suffix truncation
    description=$(truncate_suffix "$description")

    local branch_name="issue-${issue_number}-${description}"
    local worktree_path="trees/${branch_name}"

    # Check if worktree already exists
    if [ -d "$worktree_path" ]; then
        echo -e "${YELLOW}Warning: Worktree already exists at ${worktree_path}${NC}"
        exit 1
    fi

    echo "Creating worktree: $worktree_path"
    echo "Branch: $branch_name"

    # Create worktree
    git worktree add -b "$branch_name" "$worktree_path"

    # Bootstrap CLAUDE.md if it exists in main repo
    if [ -f "CLAUDE.md" ]; then
        cp "CLAUDE.md" "$worktree_path/CLAUDE.md"
        echo "Bootstrapped CLAUDE.md"
    fi

    echo -e "${GREEN}✓ Worktree created successfully${NC}"

    # Emit machine-readable path marker if requested
    if [ "$print_path" = true ]; then
        echo "__WT_WORKTREE_PATH__=$worktree_path"
    fi

    echo ""
    echo "To start working:"
    echo "  cd $worktree_path"
    echo "  claude-code"
}

# List worktrees
cmd_list() {
    echo "Active worktrees:"
    git worktree list
}

# Remove worktree
cmd_remove() {
    local issue_number="$1"
    shift
    local keep_branch=false

    # Parse flags
    while [ $# -gt 0 ]; do
        case "$1" in
            --keep-branch)
                keep_branch=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown flag: $1${NC}"
                exit 1
                ;;
        esac
    done

    if [ -z "$issue_number" ]; then
        echo -e "${RED}Error: Issue number required${NC}"
        echo "Usage: $0 remove <issue-number> [--keep-branch]"
        exit 1
    fi

    # Find worktree matching issue number
    local worktree_path
    worktree_path=$(git worktree list --porcelain | grep "^worktree " | cut -d' ' -f2 | grep "trees/issue-${issue_number}-" | head -n1)

    if [ -z "$worktree_path" ]; then
        echo -e "${YELLOW}Warning: No worktree found for issue #${issue_number}${NC}"
        exit 1
    fi

    # Resolve branch name before removing worktree
    local branch_name
    branch_name=$(git -C "$worktree_path" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "")

    if [ -z "$branch_name" ]; then
        echo -e "${YELLOW}Warning: Worktree is in detached HEAD state, skipping branch deletion${NC}"
    elif [[ ! "$branch_name" =~ ^issue-${issue_number}- ]]; then
        echo -e "${YELLOW}Warning: Branch '$branch_name' does not match expected pattern, skipping deletion${NC}"
        branch_name=""
    fi

    echo "Removing worktree: $worktree_path"

    # Remove worktree (force to handle untracked/uncommitted files)
    git worktree remove --force "$worktree_path"

    echo -e "${GREEN}✓ Worktree removed successfully${NC}"

    # Delete branch unless --keep-branch specified
    if [ "$keep_branch" = true ]; then
        echo "Kept branch: $branch_name"
    elif [ -n "$branch_name" ]; then
        if git branch -d "$branch_name" 2>/dev/null; then
            echo -e "${GREEN}✓ Branch deleted: $branch_name${NC}"
        else
            echo -e "${YELLOW}Warning: Could not delete branch '$branch_name' (may have unmerged commits)${NC}"
            echo "To force delete: git branch -D $branch_name"
        fi
    fi
}

# Prune stale worktree metadata
cmd_prune() {
    echo "Pruning stale worktree metadata..."
    git worktree prune
    echo -e "${GREEN}✓ Prune completed${NC}"
}

# Main command dispatcher
cmd="$1"
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
        echo "  $0 create <issue-number> [description]"
        echo "  $0 list"
        echo "  $0 remove <issue-number> [--keep-branch]"
        echo "  $0 prune"
        echo ""
        echo "Examples:"
        echo "  $0 create 42              # Fetch title from GitHub"
        echo "  $0 create 42 add-feature  # Use custom description"
        echo "  $0 list                   # Show all worktrees"
        echo "  $0 remove 42              # Remove worktree and branch for issue 42"
        echo "  $0 remove 42 --keep-branch  # Remove worktree but keep branch"
        exit 1
        ;;
esac
