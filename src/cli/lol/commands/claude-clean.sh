#!/usr/bin/env bash
# lol_cmd_claude_clean: Remove stale project entries from ~/.claude.json

# lol_cmd_claude_clean: Remove stale project entries from ~/.claude.json
# Runs in subshell to preserve set -e semantics
# Usage: lol_cmd_claude_clean <dry_run>
lol_cmd_claude_clean() (
    set -e

    local dry_run="$1"
    local config_path="$HOME/.claude.json"

    # Check if config file exists
    if [ ! -f "$config_path" ]; then
        echo "No Claude config file found at $config_path"
        echo "Nothing to clean."
        exit 0
    fi

    # Check if jq is available and resolve its path
    local jq_cmd
    jq_cmd=$(command -v jq 2>/dev/null) || {
        echo "Error: jq is required for this command"
        echo ""
        echo "Please install jq:"
        echo "  brew install jq    # macOS"
        echo "  apt install jq     # Ubuntu/Debian"
        exit 1
    }

    # Extract paths from .projects keys
    local projects_paths
    projects_paths=$("$jq_cmd" -r '.projects // {} | keys[]' "$config_path" 2>/dev/null || true)

    # Extract paths from .githubRepoPaths arrays
    local repo_paths
    repo_paths=$("$jq_cmd" -r '.githubRepoPaths // {} | .[] | .[]' "$config_path" 2>/dev/null || true)

    # Combine all paths and check for stale ones
    local stale_projects=()
    local stale_repo_paths=()

    # Check .projects paths
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        if [ ! -d "$path" ]; then
            stale_projects+=("$path")
        fi
    done <<< "$projects_paths"

    # Check .githubRepoPaths paths
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        if [ ! -d "$path" ]; then
            stale_repo_paths+=("$path")
        fi
    done <<< "$repo_paths"

    # Count stale entries
    local stale_projects_count=${#stale_projects[@]}
    local stale_repo_paths_count=${#stale_repo_paths[@]}
    local total_stale=$((stale_projects_count + stale_repo_paths_count))

    # If no stale entries, report and exit
    if [ $total_stale -eq 0 ]; then
        echo "No stale entries found."
        exit 0
    fi

    # Report findings
    echo "Found stale entries:"
    if [ $stale_projects_count -gt 0 ]; then
        echo "  .projects: $stale_projects_count stale key(s)"
        for path in "${stale_projects[@]}"; do
            echo "    - $path"
        done
    fi
    if [ $stale_repo_paths_count -gt 0 ]; then
        echo "  .githubRepoPaths: $stale_repo_paths_count stale path(s)"
        for path in "${stale_repo_paths[@]}"; do
            echo "    - $path"
        done
    fi
    echo ""

    # If dry-run, exit now
    if [ "$dry_run" = "1" ]; then
        echo "Dry run: no changes made."
        exit 0
    fi

    # Create temp files for stale paths (jq-friendly approach)
    local stale_projects_file
    local stale_repo_paths_file
    stale_projects_file=$(/usr/bin/mktemp)
    stale_repo_paths_file=$(/usr/bin/mktemp)

    # Write stale paths to temp files as JSON arrays
    printf '%s\n' "${stale_projects[@]}" | "$jq_cmd" -Rs 'split("\n") | map(select(. != ""))' > "$stale_projects_file"
    printf '%s\n' "${stale_repo_paths[@]}" | "$jq_cmd" -Rs 'split("\n") | map(select(. != ""))' > "$stale_repo_paths_file"

    # Apply filter using jq with slurpfile
    local tmp_file
    tmp_file=$(/usr/bin/mktemp)
    if "$jq_cmd" --slurpfile stale_projects "$stale_projects_file" \
          --slurpfile stale_repo_paths "$stale_repo_paths_file" '
        # Remove stale project keys
        .projects |= (to_entries | map(select(.key as $k | ($stale_projects[0] | index($k)) == null)) | from_entries) |
        # Remove stale paths from githubRepoPaths arrays
        .githubRepoPaths |= (to_entries | map(.value |= map(select(. as $p | ($stale_repo_paths[0] | index($p)) == null))) | from_entries) |
        # Remove empty repo entries
        .githubRepoPaths |= (to_entries | map(select(.value | length > 0)) | from_entries)
    ' "$config_path" > "$tmp_file"; then
        /bin/mv "$tmp_file" "$config_path"
        /bin/rm -f "$stale_projects_file" "$stale_repo_paths_file"
        echo "Removed $total_stale stale entries."
    else
        /bin/rm -f "$tmp_file" "$stale_projects_file" "$stale_repo_paths_file"
        echo "Error: Failed to update $config_path"
        exit 1
    fi
)
