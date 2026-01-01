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

# Locate .agentize.yaml metadata file
# Prefer trees/main/.agentize.yaml, fallback to repo_root/.agentize.yaml
locate_metadata() {
    local repo_root="$1"

    # Try trees/main/.agentize.yaml first (for worktree layout)
    if [ -f "$repo_root/trees/main/.agentize.yaml" ]; then
        echo "$repo_root/trees/main/.agentize.yaml"
        return 0
    fi

    # Fallback to repo_root/.agentize.yaml
    if [ -f "$repo_root/.agentize.yaml" ]; then
        echo "$repo_root/.agentize.yaml"
        return 0
    fi

    # Not found
    return 1
}

# Parse YAML value for a given key (lightweight parser)
# Usage: parse_yaml_value "git.default_branch" < .agentize.yaml
parse_yaml_value() {
    local key="$1"
    local section="${key%%.*}"
    local field="${key##*.}"

    # Simple state machine: look for section, then field
    local in_section=false

    while IFS= read -r line; do
        # Check for indentation before stripping whitespace
        local is_indented=false
        if [[ "$line" =~ ^[[:space:]]+ ]]; then
            is_indented=true
        fi

        # Strip leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Check if this is the section header (top-level, not indented)
        if [[ "$line" =~ ^${section}:[[:space:]]*$ ]] && [ "$is_indented" = false ]; then
            in_section=true
            continue
        fi

        # Check if we've left the section (new top-level key, not indented)
        if [[ "$line" =~ ^[a-z_]+:[[:space:]]* ]] && [ "$in_section" = true ] && [ "$is_indented" = false ]; then
            in_section=false
        fi

        # If in section, look for field (must be indented)
        if [ "$in_section" = true ] && [ "$is_indented" = true ] && [[ "$line" =~ ^${field}:[[:space:]]*(.+)$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
        fi
    done

    return 1
}

# Initialize worktree environment by creating trees/main
cmd_init() {
    # Resolve repo root
    local repo_root
    repo_root=$(wt_resolve_repo_root)
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Try to read metadata for configuration
    local metadata_file
    local trees_dir="trees"
    local main_branch=""

    metadata_file=$(locate_metadata "$repo_root" || true)
    if [ -n "$metadata_file" ] && [ -f "$metadata_file" ]; then
        # Read trees directory from metadata (optional, defaults to "trees")
        local meta_trees_dir
        meta_trees_dir=$(parse_yaml_value "worktree.trees_dir" < "$metadata_file" 2>/dev/null || true)
        if [ -n "$meta_trees_dir" ]; then
            trees_dir="$meta_trees_dir"
        fi

        # Read default branch from metadata
        main_branch=$(parse_yaml_value "git.default_branch" < "$metadata_file" 2>/dev/null || true)
    fi

    # If metadata didn't provide default branch, detect it (main or master)
    if [ -z "$main_branch" ]; then
        if git -C "$repo_root" show-ref --verify --quiet refs/heads/main; then
            main_branch="main"
        elif git -C "$repo_root" show-ref --verify --quiet refs/heads/master; then
            main_branch="master"
        else
            echo -e "${RED}Error: Cannot find main or master branch${NC}"
            return 1
        fi
    fi

    local main_worktree_path="$repo_root/${trees_dir}/main"

    # Check if trees/main already exists
    if [ -d "$main_worktree_path" ]; then
        echo -e "${YELLOW}Worktree already exists at ${main_worktree_path}${NC}"
        echo "Initialization already complete."
        return 0
    fi

    # Prune stale worktree metadata in case trees/main was manually deleted
    git -C "$repo_root" worktree prune >/dev/null 2>&1

    echo "Initializing worktree environment..."
    echo "Creating main worktree from branch: $main_branch"

    # Check if we're currently on the main branch in the repo root
    local current_branch
    current_branch=$(git -C "$repo_root" branch --show-current 2>/dev/null)

    if [ "$current_branch" = "$main_branch" ]; then
        # We need to move off the main branch first
        # Create a temporary detached HEAD state
        echo "Moving repository root off $main_branch branch..."
        git -C "$repo_root" checkout --detach HEAD >/dev/null 2>&1
    fi

    # Create trees/main worktree
    git -C "$repo_root" worktree add "$main_worktree_path" "$main_branch"

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create main worktree${NC}"
        # Try to restore the original branch if we detached
        if [ "$current_branch" = "$main_branch" ]; then
            git -C "$repo_root" checkout "$main_branch" >/dev/null 2>&1
        fi
        return 1
    fi

    # Install pre-commit hook if conditions are met
    if [ -f "$repo_root/scripts/pre-commit" ]; then
        # Check if pre_commit.enabled is set to false in metadata
        local pre_commit_enabled=true
        if [ -n "$metadata_file" ] && [ -f "$metadata_file" ]; then
            if grep -q "pre_commit:" "$metadata_file"; then
                if grep -A1 "pre_commit:" "$metadata_file" | grep -q "enabled: false"; then
                    pre_commit_enabled=false
                fi
            fi
        fi

        if [ "$pre_commit_enabled" = true ]; then
            # Get worktree-aware hooks directory
            local hooks_dir
            hooks_dir=$(git -C "$main_worktree_path" rev-parse --git-path hooks)

            # Check if hook already exists and is not ours
            if [ -f "$hooks_dir/pre-commit" ] && [ ! -L "$hooks_dir/pre-commit" ]; then
                echo "  Warning: Custom pre-commit hook detected, skipping installation"
            else
                echo "  Installing pre-commit hook..."
                mkdir -p "$hooks_dir"
                ln -sf "$repo_root/scripts/pre-commit" "$hooks_dir/pre-commit"
                echo "  Pre-commit hook installed"
            fi
        fi
    fi

    echo -e "${GREEN}✓ Initialization complete${NC}"
    echo "Main worktree created at: $main_worktree_path"
    echo ""
    echo "You can now use 'wt spawn <issue-number>' to create feature worktrees."
}

# Switch to main worktree
cmd_main() {
    # This function is designed to be used when sourced
    # When executed directly, it just shows a message

    # Resolve repo root
    local repo_root
    repo_root=$(wt_resolve_repo_root)
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Try to read metadata for trees directory
    local metadata_file
    local trees_dir="trees"

    metadata_file=$(locate_metadata "$repo_root" || true)
    if [ -n "$metadata_file" ] && [ -f "$metadata_file" ]; then
        local meta_trees_dir
        meta_trees_dir=$(parse_yaml_value "worktree.trees_dir" < "$metadata_file" 2>/dev/null || true)
        if [ -n "$meta_trees_dir" ]; then
            trees_dir="$meta_trees_dir"
        fi
    fi

    local main_worktree_path="$repo_root/${trees_dir}/main"

    # Check if trees/main exists
    if [ ! -d "$main_worktree_path" ]; then
        echo -e "${RED}Error: Main worktree not found at ${main_worktree_path}${NC}"
        echo "Run 'wt init' first to create the main worktree."
        return 1
    fi

    # Check if we're being sourced or executed
    if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
        # Direct execution - cannot change directory
        echo "Note: This command works only when sourced (via 'source setup.sh' and using 'wt main')."
        echo "To switch to main worktree: cd $main_worktree_path"
        return 0
    else
        # Sourced - can change directory
        cd "$main_worktree_path"
        echo "Switched to main worktree: $main_worktree_path"
        return 0
    fi
}

# Display help information
cmd_help() {
    cat <<'EOF'
Git Worktree Helper

Usage:
  wt init                          Initialize worktree environment (creates trees/main)
  wt main                          Switch to main worktree (when sourced)
  wt spawn <issue-number> [desc]   Create worktree for an issue
  wt list                          List all worktrees
  wt remove <issue-number>         Remove worktree for an issue
  wt prune                         Clean up stale worktree metadata
  wt help                          Display this help message

Examples:
  wt init                     # Initialize worktree environment
  wt main                     # Switch to main worktree
  wt spawn 42                 # Create worktree for issue #42 (fetches title from GitHub)
  wt spawn 42 add-feature     # Create worktree with custom description
  wt list                     # Show all worktrees
  wt remove 42                # Remove worktree for issue #42

Notes:
  - Run 'wt init' once before using 'wt spawn'
  - 'wt main' only works when sourced (via 'source setup.sh')
  - Worktrees are created in the 'trees/' directory
EOF
}

# Create worktree
cmd_create() {
    local issue_number="$1"
    local description="$2"
    local no_agent=false

    # Parse flags
    while [[ "$1" =~ ^-- ]]; do
        case "$1" in
            --no-agent)
                no_agent=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Re-assign after flag parsing
    issue_number="$1"
    description="$2"

    if [ -z "$issue_number" ]; then
        echo -e "${RED}Error: Issue number required${NC}"
        echo "Usage: cmd_create [--no-agent] <issue-number> [description]"
        return 1
    fi

    # Resolve repo root
    local repo_root
    repo_root=$(wt_resolve_repo_root)
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Try to read metadata for trees directory
    local metadata_file
    local trees_dir="trees"

    metadata_file=$(locate_metadata "$repo_root" || true)
    if [ -n "$metadata_file" ] && [ -f "$metadata_file" ]; then
        local meta_trees_dir
        meta_trees_dir=$(parse_yaml_value "worktree.trees_dir" < "$metadata_file" 2>/dev/null || true)
        if [ -n "$meta_trees_dir" ]; then
            trees_dir="$meta_trees_dir"
        fi
    fi

    # Check if trees/main exists (guard - init must be run first)
    local main_worktree_path="$repo_root/${trees_dir}/main"
    if [ ! -d "$main_worktree_path" ]; then
        echo -e "${RED}Error: Main worktree not found${NC}"
        echo "Please run 'wt init' first to initialize the worktree environment."
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

    # Try to read metadata for configuration
    local metadata_file
    local trees_dir="trees"
    local main_branch=""
    local metadata_missing=false

    metadata_file=$(locate_metadata "$repo_root" || true)
    if [ -n "$metadata_file" ] && [ -f "$metadata_file" ]; then
        # Read trees directory from metadata (optional, defaults to "trees")
        local meta_trees_dir
        meta_trees_dir=$(parse_yaml_value "worktree.trees_dir" < "$metadata_file" 2>/dev/null || true)
        if [ -n "$meta_trees_dir" ]; then
            trees_dir="$meta_trees_dir"
        fi

        # Read default branch from metadata
        main_branch=$(parse_yaml_value "git.default_branch" < "$metadata_file" 2>/dev/null || true)
    else
        metadata_missing=true
    fi

    local worktree_path="$repo_root/${trees_dir}/${branch_name}"

    # Check if worktree already exists
    if [ -d "$worktree_path" ]; then
        echo -e "${YELLOW}Warning: Worktree already exists at ${worktree_path}${NC}"
        return 1
    fi

    # If metadata didn't provide default branch, detect it (main or master)
    if [ -z "$main_branch" ]; then
        if git -C "$repo_root" show-ref --verify --quiet refs/heads/main; then
            main_branch="main"
        elif git -C "$repo_root" show-ref --verify --quiet refs/heads/master; then
            main_branch="master"
        else
            echo -e "${RED}Error: Cannot find main or master branch${NC}"
            if [ "$metadata_missing" = true ]; then
                echo -e "${YELLOW}Hint: Run 'lol init' or 'lol update' to create .agentize.yaml with project metadata${NC}"
            fi
            return 1
        fi

        # Emit one-time hint if metadata is missing
        if [ "$metadata_missing" = true ]; then
            echo -e "${YELLOW}Hint: .agentize.yaml not found. Run 'lol init' or 'lol update' to create project metadata.${NC}"
        fi
    fi

    echo "Updating $main_branch branch..."

    # Determine the working directory for git operations
    # Prefer trees/main if it exists (worktree layout), otherwise use repo_root
    local main_repo_dir="$repo_root/${trees_dir}/main"
    if [ ! -d "$main_repo_dir" ]; then
        main_repo_dir="$repo_root"
    fi

    # Checkout main branch in main repo
    git -C  "$main_repo_dir" checkout "$main_branch" || {
        echo -e "${RED}Error: Failed to checkout $main_branch${NC}"
        return 1
    }

    # Pull latest changes from origin with rebase
    git -C "$main_repo_dir" pull origin "$main_branch" --rebase || {
        echo -e "${YELLOW}Warning: Failed to pull from origin/$main_branch${NC}"
        echo "Continuing with local $main_branch..."
    }

    echo "Creating worktree: $worktree_path"
    echo "Branch: $branch_name (forked from $main_branch)"

    # Create worktree from main branch using git -C to operate on main repo
    git -C "$main_repo_dir" worktree add -b "$branch_name" "$worktree_path" "$main_branch"

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create worktree${NC}"
        return 1
    fi

    # Install pre-commit hook if conditions are met
    if [ -f "$repo_root/scripts/pre-commit" ]; then
        # Check if pre_commit.enabled is set to false in metadata
        local pre_commit_enabled=true
        if [ -n "$metadata_file" ] && [ -f "$metadata_file" ]; then
            if grep -q "pre_commit:" "$metadata_file"; then
                if grep -A1 "pre_commit:" "$metadata_file" | grep -q "enabled: false"; then
                    pre_commit_enabled=false
                fi
            fi
        fi

        if [ "$pre_commit_enabled" = true ]; then
            # Get worktree-aware hooks directory
            local hooks_dir
            hooks_dir=$(git -C "$worktree_path" rev-parse --git-path hooks)

            # Check if hook already exists and is not ours
            if [ -f "$hooks_dir/pre-commit" ] && [ ! -L "$hooks_dir/pre-commit" ]; then
                echo "  Warning: Custom pre-commit hook detected, skipping installation"
            else
                echo "  Installing pre-commit hook..."
                mkdir -p "$hooks_dir"
                ln -sf "$repo_root/scripts/pre-commit" "$hooks_dir/pre-commit"
                echo "  Pre-commit hook installed"
            fi
        fi
    fi

    echo -e "${GREEN}✓ Worktree created successfully${NC}"
    echo ""

    # Launch claude unless --no-agent flag is set
    if [ "$no_agent" = false ]; then
        cd "$worktree_path"
        claude "/issue-to-impl ${issue_number}"
    fi
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
        init)
            cmd_init
            local exit_code=$?
            cd "$original_dir"
            return $exit_code
            ;;
        main)
            # Special case: main changes directory and should NOT restore
            cmd_main
            return $?
            ;;
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
        help|--help|-h)
            cmd_help
            local exit_code=$?
            cd "$original_dir"
            return $exit_code
            ;;
        *)
            cmd_help
            cd "$original_dir"
            return 1
            ;;
    esac

    local exit_code=$?

    # Return to original directory (except for main command, handled above)
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
        init)
            cmd_init
            ;;
        main)
            cmd_main
            ;;
        spawn)
            cmd_create "$@"
            ;;
        create)
            # Legacy support for 'create' command
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
        help|--help|-h)
            cmd_help
            ;;
        *)
            cmd_help
            return 1
            ;;
    esac
}

# If script is executed (not sourced), run the CLI main function
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    wt_cli_main "$@"
    exit $?
fi
