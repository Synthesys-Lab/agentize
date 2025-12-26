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

# Helper function to convert title to branch-safe format
slugify() {
    local input="$1"
    # Remove tag prefixes like [plan][feat]: from issue titles
    # Pattern: \[[^]]*\] matches [anything] including multiple tags
    input=$(echo "$input" | sed 's/\[[^]]*\]//g' | sed 's/^[[:space:]]*://' | sed 's/^[[:space:]]*//')
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    echo "$input" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Create worktree
cmd_create() {
    local issue_number="$1"
    local description="$2"

    if [ -z "$issue_number" ]; then
        echo -e "${RED}Error: Issue number required${NC}"
        echo "Usage: $0 create <issue-number> [description]"
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

    # Bootstrap .claude as symlink to main repo's .claude
    if [ -d ".claude" ]; then
        ln -s "$(pwd)/.claude" "$worktree_path/.claude"
        echo "Bootstrapped .claude symlink"
    fi

    echo -e "${GREEN}✓ Worktree created successfully${NC}"
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

    if [ -z "$issue_number" ]; then
        echo -e "${RED}Error: Issue number required${NC}"
        echo "Usage: $0 remove <issue-number>"
        exit 1
    fi

    # Find worktree matching issue number
    local worktree_path
    worktree_path=$(git worktree list --porcelain | grep "^worktree " | cut -d' ' -f2 | grep "trees/issue-${issue_number}-" | head -n1)

    if [ -z "$worktree_path" ]; then
        echo -e "${YELLOW}Warning: No worktree found for issue #${issue_number}${NC}"
        exit 1
    fi

    echo "Removing worktree: $worktree_path"

    # Remove worktree (force to handle untracked/uncommitted files)
    git worktree remove --force "$worktree_path"

    echo -e "${GREEN}✓ Worktree removed successfully${NC}"
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
        echo "  $0 remove <issue-number>"
        echo "  $0 prune"
        echo ""
        echo "Examples:"
        echo "  $0 create 42              # Fetch title from GitHub"
        echo "  $0 create 42 add-feature  # Use custom description"
        echo "  $0 list                   # Show all worktrees"
        echo "  $0 remove 42              # Remove worktree for issue 42"
        exit 1
        ;;
esac
