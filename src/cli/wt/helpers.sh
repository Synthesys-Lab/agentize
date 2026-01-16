#!/usr/bin/env bash
# wt CLI helper functions
# Provides repository detection, path resolution, and project status helpers

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

# Configure proper fetch refspec and prune settings for bare repositories
# Arguments:
#   $1 - Repository directory (optional, defaults to current directory)
# Returns:
#   0 - Success or if no origin remote exists
#   1 - Configuration failure
wt_configure_origin_tracking() {
    local repo_dir="${1:-.}"

    # Check if origin remote exists
    if ! git -C "$repo_dir" remote get-url origin >/dev/null 2>&1; then
        return 0  # No origin remote, skip silently
    fi

    # Set fetch refspec for origin
    if ! git -C "$repo_dir" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"; then
        echo "Error: Failed to set remote.origin.fetch" >&2
        return 1
    fi

    # Enable fetch.prune
    if ! git -C "$repo_dir" config fetch.prune true; then
        echo "Error: Failed to set fetch.prune" >&2
        return 1
    fi

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

# Attempt to set issue status on the associated GitHub Projects board
# This is best-effort: failures are logged but do not block worktree creation
# Arguments:
#   $1 - issue number
#   $2 - worktree path (for context in log messages)
#   $3 - target status name (default: "In Progress")
wt_claim_issue_status() {
    local issue_no="$1"
    local worktree_path="$2"
    local status_name="${3:-In Progress}"

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

    # Use repositoryOwner response path (works for both organizations and users)
    project_graphql_id=$(echo "$project_response" | jq -r '.data.repositoryOwner.projectV2.id // empty' 2>/dev/null)
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

    # Step 3: Get Status field ID and target option ID
    local fields_response status_field_id target_option_id
    fields_response=$("$gh_graphql_script" list-fields "$project_graphql_id" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$fields_response" ]; then
        echo "Note: Could not list project fields" >&2
        return 0
    fi

    # Find Status field and target status option
    status_field_id=$(echo "$fields_response" | jq -r \
        '.data.node.fields.nodes[] | select(.name == "Status") | .id // empty' 2>/dev/null | head -1)
    if [ -z "$status_field_id" ]; then
        echo "Note: Status field not found in project" >&2
        return 0
    fi

    target_option_id=$(echo "$fields_response" | jq -r --arg status "$status_name" \
        '.data.node.fields.nodes[] | select(.name == "Status") | .options[] | select(.name == $status) | .id // empty' 2>/dev/null | head -1)
    if [ -z "$target_option_id" ]; then
        echo "Note: '$status_name' status option not found in project" >&2
        return 0
    fi

    # Step 4: Update the field value
    local update_response
    update_response=$("$gh_graphql_script" update-field "$project_graphql_id" "$item_id" "$status_field_id" "$target_option_id" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Note: Failed to update issue status" >&2
        return 0
    fi

    echo "Updated issue #$issue_no status to $status_name"
    return 0
}

# Unified interface for invoking Claude CLI with consistent flag handling
# Arguments:
#   $1 - command: Claude CLI command string (e.g., "/issue-to-impl 42", "/sync-master")
#   $2 - worktree_path: Absolute path to worktree where Claude should execute
#   $3 - yolo: Boolean ("true"/"false") for --dangerously-skip-permissions flag
#   $4 - headless: Boolean ("true"/"false") for --print flag and background execution
#   $5 - log_prefix: Prefix for log file name (e.g., "issue-42", "rebase-123")
#   $6 - model: (optional) Claude model to use (opus, sonnet, haiku)
# Returns:
#   0 - Success (headless always returns 0 immediately)
#   Non-zero - Claude invocation failure (interactive mode only)
wt_invoke_claude() {
    local command="$1"
    local worktree_path="$2"
    local yolo="$3"
    local headless="$4"
    local log_prefix="$5"
    local model="$6"

    # Build flags
    local yolo_flag=""
    local print_flag=""
    local model_flag=""
    if [ "$yolo" = true ]; then
        echo "WARNING: --yolo active; Claude will run with --dangerously-skip-permissions" >&2
        yolo_flag="--dangerously-skip-permissions"
    fi
    if [ "$headless" = true ]; then
        print_flag="--print"
    fi
    if [ -n "$model" ]; then
        model_flag="--model $model"
    fi

    if [ "$headless" = true ]; then
        # Headless mode: run in background with logging
        local log_dir="${AGENTIZE_HOME:-.}/.tmp/logs"
        if ! mkdir -p "$log_dir"; then
            echo "Error: Failed to create log directory: $log_dir" >&2
            return 1
        fi
        local log_file="$log_dir/${log_prefix}-$(date +%Y%m%d-%H%M%S).log"

        echo "Invoking Claude Code in headless mode..."
        # Run claude in a subshell with exec to fully detach from parent process.
        # Redirect stdin from /dev/null and stdout/stderr to log file to prevent
        # fd inheritance that would block the parent when using capture_output.
        (
            cd "$worktree_path" && exec claude $model_flag $yolo_flag $print_flag "$command"
        ) </dev/null >"$log_file" 2>&1 &
        local claude_pid=$!

        echo "PID: $claude_pid"
        echo "Log: $log_file"
        return 0
    else
        # Interactive mode (note: changes cwd to worktree_path)
        echo "Invoking Claude Code..."
        cd "$worktree_path" && claude $model_flag $yolo_flag "$command" || {
            echo "Warning: Failed to invoke Claude Code" >&2
            return 1
        }
        return 0
    fi
}
