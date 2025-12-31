#!/usr/bin/env bash
# Cross-project wt shell function
# Enables wt spawn/list/remove/prune from any directory

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Max suffix length (configurable via env var)
SUFFIX_MAX_LENGTH="${WORKTREE_SUFFIX_MAX_LENGTH:-10}"

# Helper function to convert title to branch-safe format
slugify() {
    local input="$1"
    # Remove tag prefixes like [plan][feat]: from issue titles
    # Pattern: \[[^]]*\] matches [anything] including multiple tags
    input=$(echo "$input" | sed 's/\[[^]]*\]//g' | sed 's/^[[:space:]]*://' | sed 's/^[[:space:]]*//')
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    # CRITICAL FIX: Add explicit hyphen squeezing using tr -s '-'
    echo "$input" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | tr -s '-' | sed 's/^-//' | sed 's/-$//'
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

        echo "Using title: $issue_title"
        description="$issue_title"
    fi

    # Always slugify the description (whether from GitHub or user-provided)
    description=$(slugify "$description")

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

    # Install pre-commit hook fallback if core.hooksPath is not configured
    local hooks_path
    hooks_path=$(git config --get core.hooksPath || true)

    if [ -z "$hooks_path" ] && [ -f "scripts/pre-commit" ]; then
        local git_dir
        git_dir=$(git -C "$worktree_path" rev-parse --git-dir)
        local hooks_dir="$git_dir/hooks"

        mkdir -p "$hooks_dir"
        cp "scripts/pre-commit" "$hooks_dir/pre-commit"
        chmod +x "$hooks_dir/pre-commit"
        echo "Installed pre-commit hook (fallback mode)"
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

# Check if we're in standalone script mode or function mode
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Standalone script mode - validate git repository
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

    # Main command dispatcher for standalone mode
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
else
    # Function mode - define wt() function
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

        # Check if wt-cli.sh exists
        if [ ! -f "$AGENTIZE_HOME/scripts/wt-cli.sh" ]; then
            echo "Error: wt-cli.sh not found at $AGENTIZE_HOME/scripts/wt-cli.sh"
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

        # Check if we're in a git repository
        if [ ! -d ".git" ] && [ ! -f ".git" ]; then
            echo -e "${RED}Error: Not in a git repository root${NC}"
            cd "$original_dir"
            return 1
        fi

        # Refuse to run from a linked worktree
        if [ -f ".git" ]; then
            echo -e "${RED}Error: Cannot run from a linked worktree${NC}"
            echo "Please run this from the main repository root"
            cd "$original_dir"
            return 1
        fi

        # Map wt subcommands to internal commands
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
fi
