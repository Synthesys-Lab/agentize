#!/usr/bin/env bash
# lol impl command implementation
# Automates the issue-to-implementation loop using wt + acw

# Main lol_cmd_impl function
# Arguments:
#   $1 - issue_no: Issue number to implement
#   $2 - backend: Backend in provider:model form (default: codex:gpt-5.2-codex)
#   $3 - max_iterations: Maximum acw iterations (default: 10)
#   $4 - yolo: Boolean flag for --yolo passthrough (0 or 1)
lol_cmd_impl() {
    local issue_no="$1"
    local backend="${2:-codex:gpt-5.2-codex}"
    local max_iterations="${3:-10}"
    local yolo="${4:-0}"

    # Validate issue number
    if [ -z "$issue_no" ] || ! [[ "$issue_no" =~ ^[0-9]+$ ]]; then
        echo "Error: Issue number is required and must be numeric" >&2
        echo "Usage: lol impl <issue-no> [--backend <provider:model>] [--max-iterations <N>] [--yolo]" >&2
        return 1
    fi

    # Validate backend format (must contain colon)
    if [[ ! "$backend" =~ : ]]; then
        echo "Error: Backend must be in provider:model format (e.g., codex:gpt-5.2-codex)" >&2
        echo "Usage: lol impl <issue-no> [--backend <provider:model>] [--max-iterations <N>] [--yolo]" >&2
        return 1
    fi

    # Split backend into provider and model
    local provider="${backend%%:*}"
    local model="${backend#*:}"

    # Validate max_iterations is numeric
    if ! [[ "$max_iterations" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations must be a positive number" >&2
        return 1
    fi

    # Step 1: Get worktree path
    local worktree_path
    worktree_path=$(wt pathto "$issue_no" 2>/dev/null)
    local wt_status=$?

    # If worktree doesn't exist, spawn it
    if [ $wt_status -ne 0 ] || [ -z "$worktree_path" ]; then
        echo "Creating worktree for issue $issue_no..."
        wt spawn "$issue_no" --no-agent || {
            echo "Error: Failed to create worktree for issue $issue_no" >&2
            return 1
        }
        worktree_path=$(wt pathto "$issue_no" 2>/dev/null)
        if [ -z "$worktree_path" ]; then
            echo "Error: Failed to get worktree path after spawn" >&2
            return 1
        fi
    fi

    # Ensure .tmp directory exists in worktree
    mkdir -p "$worktree_path/.tmp"

    # Initialize input/output files
    local input_file="$worktree_path/.tmp/impl-input.txt"
    local output_file="$worktree_path/.tmp/impl-output.txt"
    local report_file="$worktree_path/.tmp/report.txt"

    # Prefetch issue content (title/body/labels) for the initial prompt
    local issue_file="$worktree_path/.tmp/issue-${issue_no}.md"
    gh issue view "$issue_no" --json title,body,labels \
        -q '("# " + .title + "\n\n" + (if (.labels|length)>0 then "Labels: " + (.labels|map(.name)|join(", ")) + "\n\n" else "" end) + .body + "\n")' \
        > "$issue_file" 2>/dev/null
    if [ -s "$issue_file" ]; then
        echo "Implement the feature described in $issue_file" > "$input_file"
    else
        echo "Implement issue #$issue_no" > "$input_file"
        echo "Warning: failed to prefetch issue #$issue_no; using issue number prompt" >&2
    fi

    # Build yolo flag for acw
    local yolo_flag=""
    if [ "$yolo" = "1" ]; then
        yolo_flag="--yolo"
    fi

    # Step 2: Iterate until completion or max iterations
    local iter=0
    while [ $iter -lt "$max_iterations" ]; do
        iter=$((iter + 1))
        echo "Iteration $iter/$max_iterations..."

        # Run acw
        if [ -n "$yolo_flag" ]; then
            acw "$provider" "$model" "$input_file" "$output_file" $yolo_flag || {
                echo "Warning: acw exited with non-zero status on iteration $iter" >&2
            }
        else
            acw "$provider" "$model" "$input_file" "$output_file" || {
                echo "Warning: acw exited with non-zero status on iteration $iter" >&2
            }
        fi

        # Stage and commit changes for this iteration
        (cd "$worktree_path" && git add -A) || {
            echo "Error: Failed to stage changes for iteration $iter" >&2
            return 1
        }
        if (cd "$worktree_path" && ! git diff --cached --quiet); then
            (cd "$worktree_path" && git commit -m "impl: issue #$issue_no iteration $iter") || {
                echo "Error: Failed to commit iteration $iter" >&2
                return 1
            }
        else
            echo "No changes to commit for iteration $iter"
        fi

        # Check for completion marker
        if [ -f "$report_file" ]; then
            if grep -q "Issue $issue_no resolved" "$report_file"; then
                echo "Completion marker found!"
                break
            fi
        fi

        # Use output as next input
        if [ -f "$output_file" ]; then
            cp "$output_file" "$input_file"
        fi
    done

    # Step 3: Check if completed or hit max iterations
    if [ ! -f "$report_file" ] || ! grep -q "Issue $issue_no resolved" "$report_file"; then
        echo "Error: Max iteration limit ($max_iterations) reached without completion marker" >&2
        echo "To continue, increase --max-iterations or manually create .tmp/report.txt with 'Issue $issue_no resolved'" >&2
        return 1
    fi

    # Step 4: Detect remote and base branch
    local push_remote=""
    local base_branch=""

    # Detect push remote: prefer upstream, then origin
    if (cd "$worktree_path" && git remote | grep -q "^upstream$"); then
        push_remote="upstream"
    elif (cd "$worktree_path" && git remote | grep -q "^origin$"); then
        push_remote="origin"
    else
        echo "Error: No remote found (need upstream or origin)" >&2
        return 1
    fi

    # Detect base branch: prefer master, then main
    if (cd "$worktree_path" && git rev-parse --verify "refs/remotes/${push_remote}/master" >/dev/null 2>&1); then
        base_branch="master"
    elif (cd "$worktree_path" && git rev-parse --verify "refs/remotes/${push_remote}/main" >/dev/null 2>&1); then
        base_branch="main"
    else
        echo "Error: No default branch found (need master or main on $push_remote)" >&2
        return 1
    fi

    # Step 5: Push and create PR
    echo "Pushing to $push_remote and creating pull request..."

    # Get current branch name
    local branch_name
    branch_name=$(cd "$worktree_path" && git branch --show-current)

    # Push branch to remote
    (cd "$worktree_path" && git push -u "$push_remote" "$branch_name") || {
        echo "Warning: Failed to push branch to $push_remote" >&2
    }

    # Get PR title from first line of report
    local pr_title
    pr_title=$(head -n1 "$report_file")
    if [ -z "$pr_title" ]; then
        pr_title="Implement issue #$issue_no"
    fi

    # Get PR body from full report
    local pr_body
    pr_body=$(cat "$report_file")

    # Create PR using gh CLI with explicit base branch
    (cd "$worktree_path" && gh pr create --base "$base_branch" --title "$pr_title" --body "$pr_body") || {
        echo "Warning: Failed to create PR. You may need to create it manually." >&2
    }

    echo "Implementation complete for issue #$issue_no"
    return 0
}
