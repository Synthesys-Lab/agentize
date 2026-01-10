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
# SECTION 1.5: PROJECT STATUS HELPERS
# ============================================================================

# Attempt to set issue status to "In Progress" on the associated GitHub Projects board
# This is best-effort: failures are logged but do not block worktree creation
# Arguments:
#   $1 - issue number
#   $2 - worktree path (for context in log messages)
wt_claim_issue_status() {
    local issue_no="$1"
    local worktree_path="$2"

    # Check for required tools
    if ! command -v jq >/dev/null 2>&1; then
        return 0  # silently skip if jq not available
    fi

    # Find the project root (worktree path)
    local project_root="$worktree_path"
    if [ ! -d "$project_root" ]; then
        return 0
    fi

    # Look for .agentize.yaml in the worktree
    local config_file="$project_root/.agentize.yaml"
    if [ ! -f "$config_file" ]; then
        return 0  # no project config, skip silently
    fi

    # Extract project.org and project.id from .agentize.yaml
    local project_org project_id
    project_org=$(grep -E '^\s*org:' "$config_file" 2>/dev/null | head -1 | sed 's/.*org:\s*//' | tr -d '[:space:]"'"'"'')
    project_id=$(grep -E '^\s*id:' "$config_file" 2>/dev/null | head -1 | sed 's/.*id:\s*//' | tr -d '[:space:]"'"'"'')

    if [ -z "$project_org" ] || [ -z "$project_id" ]; then
        return 0  # missing project config, skip silently
    fi

    # Get repo info from git remote
    local remote_url repo_owner repo_name
    remote_url=$(git -C "$project_root" remote get-url origin 2>/dev/null)
    if [ -z "$remote_url" ]; then
        return 0
    fi

    # Parse owner/repo from remote URL (handles both HTTPS and SSH formats)
    # Shell-neutral regex capture: BASH_REMATCH for bash, match for zsh
    # One expands to the capture group, the other to empty string
    if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
        repo_owner="${BASH_REMATCH[1]}${match[1]}"
        repo_name="${BASH_REMATCH[2]}${match[2]}"
        # Remove .git suffix if present
        repo_name="${repo_name%.git}"
    else
        return 0  # couldn't parse remote URL
    fi

    # Find gh-graphql.sh script
    local gh_graphql_script=""
    if [ -n "$AGENTIZE_HOME" ] && [ -f "$AGENTIZE_HOME/scripts/gh-graphql.sh" ]; then
        gh_graphql_script="$AGENTIZE_HOME/scripts/gh-graphql.sh"
    elif [ -f "$project_root/scripts/gh-graphql.sh" ]; then
        gh_graphql_script="$project_root/scripts/gh-graphql.sh"
    else
        return 0  # gh-graphql.sh not found
    fi

    # Step 1: Look up project GraphQL ID
    local project_response project_graphql_id
    project_response=$("$gh_graphql_script" lookup-project "$project_org" "$project_id" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$project_response" ]; then
        echo "Note: Could not look up project $project_org/$project_id" >&2
        return 0
    fi

    project_graphql_id=$(echo "$project_response" | jq -r '.data.organization.projectV2.id // empty' 2>/dev/null)
    if [ -z "$project_graphql_id" ]; then
        echo "Note: Project $project_org/$project_id not found" >&2
        return 0
    fi

    # Step 2: Get issue's project item ID
    local issue_response item_id
    issue_response=$("$gh_graphql_script" get-issue-project-item "$repo_owner" "$repo_name" "$issue_no" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$issue_response" ]; then
        echo "Note: Could not look up issue #$issue_no project items" >&2
        return 0
    fi

    # Find the item matching our project
    item_id=$(echo "$issue_response" | jq -r --arg pid "$project_graphql_id" \
        '.data.repository.issue.projectItems.nodes[] | select(.project.id == $pid) | .id' 2>/dev/null | head -1)
    if [ -z "$item_id" ]; then
        echo "Note: Issue #$issue_no is not on project board $project_org/$project_id" >&2
        return 0
    fi

    # Step 3: Get Status field ID and "In Progress" option ID
    local fields_response status_field_id in_progress_option_id
    fields_response=$("$gh_graphql_script" list-fields "$project_graphql_id" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$fields_response" ]; then
        echo "Note: Could not list project fields" >&2
        return 0
    fi

    # Find Status field and "In Progress" option
    status_field_id=$(echo "$fields_response" | jq -r \
        '.data.node.fields.nodes[] | select(.name == "Status") | .id // empty' 2>/dev/null | head -1)
    if [ -z "$status_field_id" ]; then
        echo "Note: Status field not found in project" >&2
        return 0
    fi

    in_progress_option_id=$(echo "$fields_response" | jq -r \
        '.data.node.fields.nodes[] | select(.name == "Status") | .options[] | select(.name == "In Progress") | .id // empty' 2>/dev/null | head -1)
    if [ -z "$in_progress_option_id" ]; then
        echo "Note: 'In Progress' status option not found in project" >&2
        return 0
    fi

    # Step 4: Update the field value
    local update_response
    update_response=$("$gh_graphql_script" update-field "$project_graphql_id" "$item_id" "$status_field_id" "$in_progress_option_id" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Note: Failed to update issue status" >&2
        return 0
    fi

    echo "Updated issue #$issue_no status to In Progress"
    return 0
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

# wt clone: Clone repository as bare and initialize worktree environment
cmd_clone() {
    local url="$1"
    local dest="$2"

    # Validate URL is provided
    if [ -z "$url" ]; then
        echo "Error: Missing URL. Usage: wt clone <url> [destination]" >&2
        return 1
    fi

    # Infer destination if not provided
    if [ -z "$dest" ]; then
        # Get basename from URL, remove .git suffix if present, then add .git
        local base
        base=$(basename "$url")
        base="${base%.git}"
        dest="${base}.git"
    fi

    # Check if destination already exists
    if [ -e "$dest" ]; then
        echo "Error: Destination '$dest' already exists" >&2
        return 1
    fi

    # Clone as bare repository
    if ! git clone --bare "$url" "$dest"; then
        echo "Error: Failed to clone repository" >&2
        return 1
    fi

    # Change into the bare repo and initialize
    cd "$dest" || {
        echo "Error: Failed to change into $dest" >&2
        return 1
    }

    # Initialize worktree environment
    if ! cmd_init; then
        echo "Error: Failed to initialize worktree environment" >&2
        return 1
    fi

    # Change to trees/main (only works when sourced)
    cmd_goto main

    return 0
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
    local headless=false

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
            --headless)
                headless=true
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

    # Attempt to claim issue status as "In Progress" (best-effort)
    wt_claim_issue_status "$issue_no" "$worktree_path" || true

    # Invoke Claude if not disabled
    if [ "$no_agent" = false ] && command -v claude >/dev/null 2>&1; then
        local yolo_flag=""
        local print_flag=""
        if [ "$yolo" = true ]; then
            echo "WARNING: --yolo active; Claude will run with --dangerously-skip-permissions" >&2
            yolo_flag="--dangerously-skip-permissions"
        fi
        if [ "$headless" = true ]; then
            print_flag="--print"
        fi

        if [ "$headless" = true ]; then
            # Setup log file for headless mode
            local log_dir="${AGENTIZE_HOME:-.}/.tmp/logs"
            mkdir -p "$log_dir"
            local log_file="$log_dir/issue-${issue_no}-$(date +%Y%m%d-%H%M%S).log"
            echo "Invoking Claude Code in headless mode..."
            # Run claude in a subshell with exec to fully detach from parent process.
            # Redirect stdin from /dev/null and stdout/stderr to log file to prevent
            # fd inheritance that would block the parent when using capture_output.
            (
                cd "$worktree_path" && exec claude $yolo_flag $print_flag "/issue-to-impl $issue_no"
            ) </dev/null >"$log_file" 2>&1 &
            local claude_pid=$!
            echo "PID: $claude_pid"
            echo "Log: $log_file"
        else
            echo "Invoking Claude Code..."
            cd "$worktree_path" && claude $yolo_flag "/issue-to-impl $issue_no" || {
                echo "Warning: Failed to invoke Claude Code" >&2
            }
        fi
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

# wt rebase: Rebase PR's worktree onto default branch using Claude Code session
cmd_rebase() {
    local pr_no=""
    local headless=false
    local yolo=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --headless)
                headless=true
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
                if [ -z "$pr_no" ]; then
                    pr_no="$1"
                else
                    echo "Error: Multiple PR numbers provided" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$pr_no" ]; then
        echo "Error: Missing PR number. Usage: wt rebase <pr-no> [--headless] [--yolo]" >&2
        return 1
    fi

    # Validate PR number is numeric
    if ! [[ "$pr_no" =~ ^[0-9]+$ ]]; then
        echo "Error: PR number must be numeric" >&2
        return 1
    fi

    # Check if gh CLI is available
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: gh CLI is required for rebase command" >&2
        return 1
    fi

    # Fetch PR metadata
    local pr_data
    pr_data=$(gh pr view "$pr_no" --json headRefName,closingIssuesReferences,body 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error: PR #$pr_no not found" >&2
        return 1
    fi

    # Resolve issue number using fallbacks
    local issue_no=""

    # Fallback 1: Extract from branch name (issue-N or issue-N-*)
    local head_ref
    head_ref=$(echo "$pr_data" | grep -o '"headRefName":"[^"]*"' | sed 's/"headRefName":"//;s/"//')
    # Shell-neutral regex capture: BASH_REMATCH for bash, match for zsh
    # One expands to the capture group, the other to empty string
    if [[ "$head_ref" =~ ^issue-([0-9]+) ]]; then
        issue_no="${BASH_REMATCH[1]}${match[1]}"
    fi

    # Fallback 2: closingIssuesReferences (if issue_no still empty)
    if [ -z "$issue_no" ]; then
        # Extract first issue number from closingIssuesReferences
        issue_no=$(echo "$pr_data" | grep -o '"closingIssuesReferences":\[{"number":[0-9]*' | grep -o '[0-9]*$' | head -1)
    fi

    # Fallback 3: Search PR body for #N pattern
    if [ -z "$issue_no" ]; then
        local body
        body=$(echo "$pr_data" | grep -o '"body":"[^"]*"' | sed 's/"body":"//;s/"$//' | head -1)
        # Look for #NNN pattern
        issue_no=$(echo "$body" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
    fi

    if [ -z "$issue_no" ]; then
        echo "Error: Could not resolve issue number from PR #$pr_no" >&2
        echo "Tried:" >&2
        echo "  - Branch name: $head_ref" >&2
        echo "  - closingIssuesReferences: (none found)" >&2
        echo "  - PR body: (no #N pattern found)" >&2
        return 1
    fi

    # Resolve worktree path
    local worktree_path
    worktree_path=$(wt_resolve_worktree "$issue_no")
    if [ $? -ne 0 ] || [ -z "$worktree_path" ] || [ ! -d "$worktree_path" ]; then
        echo "Error: Worktree not found for issue #$issue_no" >&2
        return 1
    fi

    # Check if Claude is available
    if ! command -v claude >/dev/null 2>&1; then
        echo "Error: claude CLI is required for rebase command" >&2
        return 1
    fi

    # Build Claude flags
    local yolo_flag=""
    local print_flag=""
    if [ "$yolo" = true ]; then
        echo "WARNING: --yolo active; Claude will run with --dangerously-skip-permissions" >&2
        yolo_flag="--dangerously-skip-permissions"
    fi
    if [ "$headless" = true ]; then
        print_flag="--print"
    fi

    # Invoke Claude to perform the rebase
    if [ "$headless" = true ]; then
        # Headless mode: run in background with logging
        local log_dir="${AGENTIZE_HOME:-.}/.tmp/logs"
        mkdir -p "$log_dir"
        local log_file="$log_dir/rebase-${pr_no}-$(date +%Y%m%d-%H%M%S).log"

        echo "Invoking Claude Code to rebase PR #$pr_no in headless mode..."
        # Run claude in a subshell with exec to fully detach from parent process.
        # Redirect stdin from /dev/null and stdout/stderr to log file to prevent
        # fd inheritance that would block the parent when using capture_output.
        (
            cd "$worktree_path" && exec claude $yolo_flag $print_flag "/sync-master"
        ) </dev/null >"$log_file" 2>&1 &
        local claude_pid=$!

        echo "PID: $claude_pid"
        echo "Log: $log_file"
        return 0
    else
        # Interactive mode
        echo "Invoking Claude Code to rebase PR #$pr_no..."
        cd "$worktree_path" && claude $yolo_flag "/sync-master" || {
            echo "Warning: Claude Code rebase session failed" >&2
            return 1
        }
        return 0
    fi
}

# wt help: Show help message
cmd_help() {
    cat <<'EOF'
wt: Git worktree helper for bare repositories

USAGE:
  wt <command> [options]

COMMANDS:
  clone <url> [dest]  Clone repository as bare and initialize worktrees
  common              Print the git common directory (bare repo path)
  init                Initialize worktree environment (run once per repo)
  goto <target>       Change directory to worktree (target: main or issue-no)
  spawn <issue-no>    Create new worktree for issue (from default branch)
  list                List all worktrees
  remove <issue-no>   Remove worktree for issue
  prune               Clean up stale worktree metadata
  purge               Remove worktrees for closed GitHub issues
  pathto <target>     Print absolute path to worktree (target: main or issue-no)
  rebase <pr-no>      Rebase PR's worktree onto default branch
  help                Show this help message

OPTIONS (spawn):
  --no-agent          Skip automatic Claude invocation
  --yolo              Skip permission prompts
  --headless          Run Claude in non-interactive mode (for server daemon)

OPTIONS (remove):
  --delete-branch     Delete branch even if unmerged
  -D, --force         Alias for --delete-branch

OPTIONS (rebase):
  --headless          Run Claude in non-interactive mode (for server daemon)
  --yolo              Skip permission prompts

REQUIREMENTS:
  - Bare git repository (create with: git clone --bare, or wt clone)
  - gh CLI (for spawn validation and purge)

EXAMPLES:
  wt clone https://github.com/org/repo.git   # Clone and initialize
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
        clone)
            cmd_clone "$@"
            ;;
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
        pathto)
            wt_resolve_worktree "$@"
            ;;
        rebase)
            cmd_rebase "$@"
            ;;
        help|--help|-h|"")
            cmd_help
            ;;
        --complete)
            # Completion helper (to be implemented)
            local topic="$1"
            case "$topic" in
                commands)
                    echo "clone"
                    echo "common"
                    echo "init"
                    echo "goto"
                    echo "spawn"
                    echo "list"
                    echo "remove"
                    echo "prune"
                    echo "purge"
                    echo "pathto"
                    echo "rebase"
                    echo "help"
                    ;;
                spawn-flags)
                    echo "--yolo"
                    echo "--no-agent"
                    echo "--headless"
                    ;;
                remove-flags)
                    echo "--delete-branch"
                    echo "-D"
                    echo "--force"
                    ;;
                rebase-flags)
                    echo "--headless"
                    echo "--yolo"
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
