#!/usr/bin/env bash
# planner pipeline orchestration
# Multi-agent debate pipeline with parallel critique and reducer stages

# Render a prompt by concatenating agent base prompt, optional plan-guideline, and context
# Usage: _planner_render_prompt <output-file> <agent-md-path> <include-plan-guideline> <feature-desc> [context-file]
_planner_render_prompt() {
    local output_file="$1"
    local agent_md="$2"
    local include_plan_guideline="$3"
    local feature_desc="$4"
    local context_file="${5:-}"

    local repo_root="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"

    # Start with agent base prompt (strip YAML frontmatter)
    sed '/^---$/,/^---$/d' "$repo_root/$agent_md" > "$output_file"

    # Append plan-guideline content if requested (strip YAML frontmatter)
    if [ "$include_plan_guideline" = "true" ]; then
        local plan_guideline="$repo_root/.claude-plugin/skills/plan-guideline/SKILL.md"
        if [ -f "$plan_guideline" ]; then
            echo "" >> "$output_file"
            echo "---" >> "$output_file"
            echo "" >> "$output_file"
            echo "# Planning Guidelines" >> "$output_file"
            echo "" >> "$output_file"
            sed '/^---$/,/^---$/d' "$plan_guideline" >> "$output_file"
        fi
    fi

    # Append feature description
    echo "" >> "$output_file"
    echo "---" >> "$output_file"
    echo "" >> "$output_file"
    echo "# Feature Request" >> "$output_file"
    echo "" >> "$output_file"
    echo "$feature_desc" >> "$output_file"

    # Append context from previous stage if provided
    if [ -n "$context_file" ] && [ -f "$context_file" ]; then
        echo "" >> "$output_file"
        echo "---" >> "$output_file"
        echo "" >> "$output_file"
        echo "# Previous Stage Output" >> "$output_file"
        echo "" >> "$output_file"
        cat "$context_file" >> "$output_file"
    fi
}

# Log a message to stderr, respecting verbose mode
# Usage: _planner_log <verbose> <message>
_planner_log() {
    local verbose="$1"
    shift
    if [ "$verbose" = "true" ]; then
        echo "$@" >&2
    fi
}

# Log a stage header (always printed regardless of verbose)
# Usage: _planner_stage <stage-label>
_planner_stage() {
    echo "$@" >&2
}

# Run the full multi-agent debate pipeline
# Usage: _planner_run_pipeline "<feature-description>" [issue-mode] [verbose]
_planner_run_pipeline() {
    local feature_desc="$1"
    local issue_mode="${2:-true}"
    local verbose="${3:-false}"
    local repo_root="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)

    # Ensure .tmp directory exists
    mkdir -p "$repo_root/.tmp"

    # Determine artifact prefix: issue-N or timestamp
    local issue_number=""
    local prefix_name=""

    if [ "$issue_mode" = "true" ]; then
        issue_number=$(_planner_issue_create "$feature_desc")
        if [ -n "$issue_number" ]; then
            prefix_name="issue-${issue_number}"
            _planner_stage "Created placeholder issue #${issue_number}"
        else
            echo "Warning: Issue creation failed, falling back to timestamp artifacts" >&2
            prefix_name="${timestamp}"
        fi
    else
        prefix_name="${timestamp}"
    fi

    local prefix="$repo_root/.tmp/${prefix_name}"

    # File paths for each stage
    local understander_input="${prefix}-understander-input.md"
    local understander_output="${prefix}-understander.txt"
    local bold_input="${prefix}-bold-input.md"
    local bold_output="${prefix}-bold.txt"
    local critique_input="${prefix}-critique-input.md"
    local critique_output="${prefix}-critique.txt"
    local reducer_input="${prefix}-reducer-input.md"
    local reducer_output="${prefix}-reducer.txt"

    _planner_stage "Starting multi-agent debate pipeline..."
    _planner_log "$verbose" "Feature: $feature_desc"
    _planner_log "$verbose" "Artifacts prefix: ${prefix_name}"
    _planner_log "$verbose" ""

    # ── Stage 1: Understander ──
    _planner_stage "Stage 1/5: Running understander (sonnet)..."
    _planner_render_prompt "$understander_input" \
        ".claude-plugin/agents/understander.md" \
        "false" \
        "$feature_desc"

    acw claude sonnet "$understander_input" "$understander_output" \
        --tools "Read,Grep,Glob"
    local understander_exit=$?

    if [ $understander_exit -ne 0 ] || [ ! -s "$understander_output" ]; then
        echo "Error: Understander stage failed (exit code: $understander_exit)" >&2
        return 2
    fi
    _planner_log "$verbose" "  Understander complete: $understander_output"
    _planner_log "$verbose" ""

    # ── Stage 2: Bold-proposer ──
    _planner_stage "Stage 2/5: Running bold-proposer (opus)..."
    _planner_render_prompt "$bold_input" \
        ".claude-plugin/agents/bold-proposer.md" \
        "true" \
        "$feature_desc" \
        "$understander_output"

    acw claude opus "$bold_input" "$bold_output" \
        --tools "Read,Grep,Glob,WebSearch,WebFetch" \
        --permission-mode plan
    local bold_exit=$?

    if [ $bold_exit -ne 0 ] || [ ! -s "$bold_output" ]; then
        echo "Error: Bold-proposer stage failed (exit code: $bold_exit)" >&2
        return 2
    fi
    _planner_log "$verbose" "  Bold-proposer complete: $bold_output"
    _planner_log "$verbose" ""

    # ── Stage 3 & 4: Critique and Reducer (parallel) ──
    _planner_stage "Stage 3-4/5: Running critique and reducer in parallel (opus)..."

    # Critique
    _planner_render_prompt "$critique_input" \
        ".claude-plugin/agents/proposal-critique.md" \
        "true" \
        "$feature_desc" \
        "$bold_output"

    acw claude opus "$critique_input" "$critique_output" \
        --tools "Read,Grep,Glob,Bash" &
    local critique_pid=$!

    # Reducer
    _planner_render_prompt "$reducer_input" \
        ".claude-plugin/agents/proposal-reducer.md" \
        "true" \
        "$feature_desc" \
        "$bold_output"

    acw claude opus "$reducer_input" "$reducer_output" \
        --tools "Read,Grep,Glob" &
    local reducer_pid=$!

    # Wait for both and capture exit codes
    local critique_exit=0
    local reducer_exit=0
    wait $critique_pid || critique_exit=$?
    wait $reducer_pid || reducer_exit=$?

    if [ $critique_exit -ne 0 ] || [ ! -s "$critique_output" ]; then
        echo "Error: Critique stage failed (exit code: $critique_exit)" >&2
        return 2
    fi
    _planner_log "$verbose" "  Critique complete: $critique_output"

    if [ $reducer_exit -ne 0 ] || [ ! -s "$reducer_output" ]; then
        echo "Error: Reducer stage failed (exit code: $reducer_exit)" >&2
        return 2
    fi
    _planner_log "$verbose" "  Reducer complete: $reducer_output"
    _planner_log "$verbose" ""

    # ── Stage 5: External Consensus ──
    _planner_stage "Stage 5/5: Running external consensus synthesis..."

    local consensus_script="${_PLANNER_CONSENSUS_SCRIPT:-$repo_root/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh}"

    if [ ! -f "$consensus_script" ]; then
        echo "Error: Consensus script not found: $consensus_script" >&2
        return 2
    fi

    local consensus_path
    consensus_path=$("$consensus_script" "$bold_output" "$critique_output" "$reducer_output")
    local consensus_exit=$?

    if [ $consensus_exit -ne 0 ] || [ -z "$consensus_path" ]; then
        echo "Error: Consensus stage failed (exit code: $consensus_exit)" >&2
        return 2
    fi

    _planner_log "$verbose" ""
    _planner_stage "Pipeline complete!"
    _planner_log "$verbose" "Consensus plan: $consensus_path"
    _planner_log "$verbose" ""

    # Publish to GitHub issue if in issue mode and issue was created
    if [ "$issue_mode" = "true" ] && [ -n "$issue_number" ]; then
        _planner_stage "Publishing plan to issue #${issue_number}..."
        _planner_issue_publish "$issue_number" "$feature_desc" "$consensus_path" || {
            echo "Warning: Failed to publish plan to issue #${issue_number}" >&2
        }
    fi

    # Output consensus path to stdout
    echo "$consensus_path"
    return 0
}
