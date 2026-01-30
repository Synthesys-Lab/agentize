#!/usr/bin/env bash
# planner pipeline orchestration
# Multi-agent debate pipeline with parallel critique and reducer stages

# ── Rendering helpers (color, animation, timing) ──

# Check if color output is enabled on stderr
# Returns 0 if color should be used, 1 otherwise
_planner_color_enabled() {
    [ -z "${NO_COLOR:-}" ] && [ -z "${PLANNER_NO_COLOR:-}" ] && [ -t 2 ]
}

# Check if animation is enabled on stderr
_planner_anim_enabled() {
    [ -z "${PLANNER_NO_ANIM:-}" ] && [ -t 2 ]
}

# Print colored "Feature:" label and description to stderr
_planner_print_feature() {
    local desc="$1"
    term_label "Feature:" "$desc" "info"
}

# Start a timer, outputs epoch seconds
_planner_timer_start() {
    date +%s
}

# Log elapsed time for an agent stage to stderr
# Usage: _planner_timer_log <agent-name> <start_epoch>
_planner_timer_log() {
    local agent="$1"
    local start="$2"
    local end
    end=$(date +%s)
    local elapsed=$(( end - start ))
    echo "  ${agent} agent runs ${elapsed}s" >&2
}

# Animation PID storage
_PLANNER_ANIM_PID=""

# Start animated dots on stderr for a stage label
# Usage: _planner_anim_start "<label>"
_planner_anim_start() {
    local label="$1"
    _PLANNER_ANIM_PID=""
    if ! _planner_anim_enabled; then
        echo "$label" >&2
        return
    fi
    (
        local dots=".."
        local growing=1
        while true; do
            term_clear_line
            printf '%s %s' "$label" "$dots" >&2
            sleep 0.4
            if [ "$growing" -eq 1 ]; then
                dots="${dots}."
                [ ${#dots} -ge 5 ] && growing=0
            else
                dots="${dots%?}"
                [ ${#dots} -le 2 ] && growing=1
            fi
        done
    ) &
    _PLANNER_ANIM_PID=$!
    disown %+ 2>/dev/null || true  # prevent job-control termination output in interactive shells
}

# Stop animation and print a clean final line
# Usage: _planner_anim_stop
_planner_anim_stop() {
    if [ -n "$_PLANNER_ANIM_PID" ]; then
        kill "$_PLANNER_ANIM_PID" 2>/dev/null
        wait "$_PLANNER_ANIM_PID" 2>/dev/null
        term_clear_line
        _PLANNER_ANIM_PID=""
    fi
}

# Print styled "issue created: <url>" to stderr
_planner_print_issue_created() {
    local url="$1"
    term_label "issue created:" "$url" "success"
}

# ── Backend parsing and invocation ──

# Validate backend spec format (provider:model). Empty is allowed.
# Usage: _planner_validate_backend "<spec>" "<label>"
_planner_validate_backend() {
    local spec="$1"
    local label="${2:-backend}"
    if [ -z "$spec" ]; then
        return 0
    fi
    case "$spec" in
        *:*)
            ;;
        *)
            echo "Error: Invalid ${label} backend '$spec' (expected provider:model)" >&2
            return 1
            ;;
    esac
    local provider="${spec%%:*}"
    local model="${spec#*:}"
    if [ -z "$provider" ] || [ -z "$model" ]; then
        echo "Error: Invalid ${label} backend '$spec' (expected provider:model)" >&2
        return 1
    fi
    return 0
}

# Load planner backends from .agentize.local.yaml (planner.* keys).
# Outputs newline-delimited key=value pairs for configured keys.
# Usage: _planner_load_backend_config <repo-root> <start-dir>
_planner_load_backend_config() {
    local repo_root="$1"
    local start_dir="$2"
    PLANNER_CONFIG_REPO_ROOT="$repo_root" \
    PLANNER_CONFIG_START_DIR="$start_dir" \
    python3 - <<'PY'
import os
import sys
from pathlib import Path

repo_root = Path(os.environ.get("PLANNER_CONFIG_REPO_ROOT", ""))
start_dir = os.environ.get("PLANNER_CONFIG_START_DIR")

if not repo_root:
    print("Error: Missing repo root for planner config lookup", file=sys.stderr)
    sys.exit(1)

plugin_dir = repo_root / ".claude-plugin"
if not plugin_dir.is_dir():
    print(f"Error: Planner config helper not found: {plugin_dir}", file=sys.stderr)
    sys.exit(1)

sys.path.insert(0, str(plugin_dir))

def _fallback_helpers():
    import os
    from pathlib import Path
    try:
        import yaml
    except Exception as exc:
        print(f"Error: Failed to import PyYAML: {exc}", file=sys.stderr)
        sys.exit(1)

    def find_local_config_file(start_dir=None):
        if start_dir is None:
            start_dir = Path.cwd()
        current = Path(start_dir).resolve()
        while True:
            candidate = current / ".agentize.local.yaml"
            if candidate.is_file():
                return candidate
            parent = current.parent
            if parent == current:
                break
            current = parent

        agentize_home = os.getenv("AGENTIZE_HOME")
        if agentize_home:
            candidate = Path(agentize_home) / ".agentize.local.yaml"
            if candidate.is_file():
                return candidate

        home = os.getenv("HOME")
        if home:
            candidate = Path(home) / ".agentize.local.yaml"
            if candidate.is_file():
                return candidate

        return None

    def parse_yaml_file(path):
        with open(path, "r") as f:
            return yaml.safe_load(f) or {}

    return find_local_config_file, parse_yaml_file

try:
    from lib.local_config_io import find_local_config_file, parse_yaml_file
except Exception:
    find_local_config_file, parse_yaml_file = _fallback_helpers()

try:
    path = find_local_config_file(Path(start_dir) if start_dir else None)
    if path is None:
        sys.exit(0)
    config = parse_yaml_file(path)
    planner = config.get("planner")
    if planner is None:
        sys.exit(0)
    if not isinstance(planner, dict):
        print(f"Error: planner section in {path} must be a mapping", file=sys.stderr)
        sys.exit(1)
    for key in ("backend", "understander", "bold", "critique", "reducer"):
        if key not in planner:
            continue
        value = planner.get(key)
        if value is None:
            continue
        if not isinstance(value, str):
            print(f"Error: planner.{key} in {path} must be a string", file=sys.stderr)
            sys.exit(1)
        value = value.strip()
        if not value:
            continue
        print(f"{key}={value}")
except Exception as exc:
    print(f"Error: Failed to load planner config: {exc}", file=sys.stderr)
    sys.exit(1)
PY
}

# Invoke acw for a backend spec with optional Claude-only flags.
# Usage: _planner_acw_run <backend-spec> <input> <output> <tools> [permission-mode]
_planner_acw_run() {
    local backend_spec="$1"
    local input="$2"
    local output="$3"
    local tools="$4"
    local permission_mode="${5:-}"
    local provider=""
    local model=""

    IFS=':' read -r provider model <<< "$backend_spec"

    local -a args=()
    if [ "$provider" = "claude" ]; then
        args+=(--tools "$tools")
        if [ -n "$permission_mode" ]; then
            args+=(--permission-mode "$permission_mode")
        fi
    fi

    acw "$provider" "$model" "$input" "$output" "${args[@]}"
}

# ── Prompt rendering ──

# Render a prompt by concatenating agent base prompt, optional plan-guideline, and context
# Usage: _planner_render_prompt <output-file> <agent-md-path> <include-plan-guideline> <feature-desc> [context-file]
_planner_render_prompt() {
    local output_file="$1"
    local agent_md="$2"
    local include_plan_guideline="$3"
    local feature_desc="$4"
    local context_file="${5:-}"

    local repo_root="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    if [ -z "$repo_root" ] || [ ! -d "$repo_root" ]; then
        echo "Error: Could not determine repo root. Set AGENTIZE_HOME or run inside a git repo." >&2
        return 1
    fi
    local agent_path="$repo_root/$agent_md"
    if [ ! -f "$agent_path" ]; then
        echo "Error: Agent prompt not found: $agent_path" >&2
        return 1
    fi

    # Start with agent base prompt (strip YAML frontmatter)
    sed '/^---$/,/^---$/d' "$agent_path" > "$output_file"

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
    return 0
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
# Usage: _planner_run_pipeline "<feature-description>" [issue-mode] [verbose] [refine-issue-number]
_planner_run_pipeline() {
    local feature_desc="$1"
    local issue_mode="${2:-true}"
    local verbose="${3:-false}"
    local refine_issue_number="${4:-}"
    local repo_root="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    if [ -z "$repo_root" ] || [ ! -d "$repo_root" ]; then
        echo "Error: Could not determine repo root. Set AGENTIZE_HOME or run inside a git repo." >&2
        return 1
    fi
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)

    # Ensure .tmp directory exists
    mkdir -p "$repo_root/.tmp"

    # Determine artifact prefix: issue-N, issue-refine-N, or timestamp
    local issue_number=""
    local prefix_name=""
    local refine_instructions=""

    if [ -n "$refine_issue_number" ]; then
        refine_instructions="$feature_desc"
        local issue_body
        local issue_body_tmp
        issue_body_tmp=$(mktemp)
        if ! _planner_issue_fetch "$refine_issue_number" >"$issue_body_tmp"; then
            rm -f "$issue_body_tmp"
            echo "Error: Failed to fetch issue #${refine_issue_number} for refinement" >&2
            return 1
        fi
        issue_body=$(cat "$issue_body_tmp")
        rm -f "$issue_body_tmp"
        if ! echo "$issue_body" | grep -Eq "Implementation Plan:|Consensus Plan:"; then
            echo "Warning: Issue #${refine_issue_number} does not look like a plan (missing Implementation/Consensus Plan headers)" >&2
        fi
        feature_desc="$issue_body"
        if [ -n "$refine_instructions" ]; then
            feature_desc="${feature_desc}"$'\n\n'"Refinement focus:"$'\n'"${refine_instructions}"
        fi
        issue_number="$refine_issue_number"
        prefix_name="issue-refine-${refine_issue_number}"
    elif [ "$issue_mode" = "true" ]; then
        local issue_number_tmp
        issue_number_tmp=$(mktemp)
        if _planner_issue_create "$feature_desc" >"$issue_number_tmp"; then
            issue_number=$(cat "$issue_number_tmp")
        else
            issue_number=""
        fi
        rm -f "$issue_number_tmp"
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

    local config_start_dir="${PWD:-$(pwd)}"
    local planner_backend=""
    local planner_understander=""
    local planner_bold=""
    local planner_critique=""
    local planner_reducer=""
    local backend_config
    backend_config=$(_planner_load_backend_config "$repo_root" "$config_start_dir") || return 1
    if [ -n "$backend_config" ]; then
        while IFS='=' read -r key value; do
            case "$key" in
                backend)
                    planner_backend="$value"
                    ;;
                understander)
                    planner_understander="$value"
                    ;;
                bold)
                    planner_bold="$value"
                    ;;
                critique)
                    planner_critique="$value"
                    ;;
                reducer)
                    planner_reducer="$value"
                    ;;
            esac
        done <<< "$backend_config"
    fi

    if ! _planner_validate_backend "$planner_backend" "planner.backend"; then
        return 1
    fi
    if ! _planner_validate_backend "$planner_understander" "planner.understander"; then
        return 1
    fi
    if ! _planner_validate_backend "$planner_bold" "planner.bold"; then
        return 1
    fi
    if ! _planner_validate_backend "$planner_critique" "planner.critique"; then
        return 1
    fi
    if ! _planner_validate_backend "$planner_reducer" "planner.reducer"; then
        return 1
    fi

    local default_understander="claude:sonnet"
    local default_bold="claude:opus"
    local default_critique="claude:opus"
    local default_reducer="claude:opus"
    if [ -n "$planner_backend" ]; then
        default_understander="$planner_backend"
        default_bold="$planner_backend"
        default_critique="$planner_backend"
        default_reducer="$planner_backend"
    fi
    local understander_backend="${planner_understander:-$default_understander}"
    local bold_backend="${planner_bold:-$default_bold}"
    local critique_backend="${planner_critique:-$default_critique}"
    local reducer_backend="${planner_reducer:-$default_reducer}"

    _planner_stage "Starting multi-agent debate pipeline..."
    _planner_print_feature "$feature_desc"
    _planner_log "$verbose" "Artifacts prefix: ${prefix_name}"
    _planner_log "$verbose" ""

    # ── Stage 1: Understander ──
    local t_understander
    t_understander=$(_planner_timer_start)
    _planner_anim_start "Stage 1/5: Running understander (${understander_backend})"
    if ! _planner_render_prompt "$understander_input" \
        ".claude-plugin/agents/understander.md" \
        "false" \
        "$feature_desc"; then
        _planner_anim_stop
        echo "Error: Understander prompt rendering failed" >&2
        return 2
    fi

    _planner_acw_run "$understander_backend" "$understander_input" "$understander_output" \
        "Read,Grep,Glob"
    local understander_exit=$?
    _planner_anim_stop

    if [ $understander_exit -ne 0 ] || [ ! -s "$understander_output" ]; then
        echo "Error: Understander stage failed (exit code: $understander_exit)" >&2
        return 2
    fi
    _planner_timer_log "understander" "$t_understander"
    _planner_log "$verbose" "  Understander complete: $understander_output"
    _planner_log "$verbose" ""

    # ── Stage 2: Bold-proposer ──
    local t_bold
    t_bold=$(_planner_timer_start)
    _planner_anim_start "Stage 2/5: Running bold-proposer (${bold_backend})"
    if ! _planner_render_prompt "$bold_input" \
        ".claude-plugin/agents/bold-proposer.md" \
        "true" \
        "$feature_desc" \
        "$understander_output"; then
        _planner_anim_stop
        echo "Error: Bold-proposer prompt rendering failed" >&2
        return 2
    fi

    _planner_acw_run "$bold_backend" "$bold_input" "$bold_output" \
        "Read,Grep,Glob,WebSearch,WebFetch" \
        "plan"
    local bold_exit=$?
    _planner_anim_stop

    if [ $bold_exit -ne 0 ] || [ ! -s "$bold_output" ]; then
        echo "Error: Bold-proposer stage failed (exit code: $bold_exit)" >&2
        return 2
    fi
    _planner_timer_log "bold-proposer" "$t_bold"
    _planner_log "$verbose" "  Bold-proposer complete: $bold_output"
    _planner_log "$verbose" ""

    # ── Stage 3 & 4: Critique and Reducer (parallel) ──
    local t_parallel
    t_parallel=$(_planner_timer_start)
    _planner_anim_start "Stage 3-4/5: Running critique and reducer in parallel (${critique_backend}, ${reducer_backend})"

    # Critique
    if ! _planner_render_prompt "$critique_input" \
        ".claude-plugin/agents/proposal-critique.md" \
        "true" \
        "$feature_desc" \
        "$bold_output"; then
        _planner_anim_stop
        echo "Error: Critique prompt rendering failed" >&2
        return 2
    fi

    _planner_acw_run "$critique_backend" "$critique_input" "$critique_output" \
        "Read,Grep,Glob,Bash" &
    local critique_pid=$!

    # Reducer
    if ! _planner_render_prompt "$reducer_input" \
        ".claude-plugin/agents/proposal-reducer.md" \
        "true" \
        "$feature_desc" \
        "$bold_output"; then
        _planner_anim_stop
        echo "Error: Reducer prompt rendering failed" >&2
        return 2
    fi

    _planner_acw_run "$reducer_backend" "$reducer_input" "$reducer_output" \
        "Read,Grep,Glob" &
    local reducer_pid=$!

    # Wait for both and capture exit codes
    local critique_exit=0
    local reducer_exit=0
    wait $critique_pid || critique_exit=$?
    wait $reducer_pid || reducer_exit=$?
    _planner_anim_stop

    if [ $critique_exit -ne 0 ] || [ ! -s "$critique_output" ]; then
        echo "Error: Critique stage failed (exit code: $critique_exit)" >&2
        return 2
    fi
    _planner_timer_log "critique" "$t_parallel"
    _planner_log "$verbose" "  Critique complete: $critique_output"

    if [ $reducer_exit -ne 0 ] || [ ! -s "$reducer_output" ]; then
        echo "Error: Reducer stage failed (exit code: $reducer_exit)" >&2
        return 2
    fi
    _planner_timer_log "reducer" "$t_parallel"
    _planner_log "$verbose" "  Reducer complete: $reducer_output"
    _planner_log "$verbose" ""

    # ── Stage 5: External Consensus ──
    local t_consensus
    t_consensus=$(_planner_timer_start)
    _planner_anim_start "Stage 5/5: Running external consensus synthesis"

    local consensus_script="${_PLANNER_CONSENSUS_SCRIPT:-$repo_root/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh}"

    if [ ! -f "$consensus_script" ]; then
        _planner_anim_stop
        echo "Error: Consensus script not found: $consensus_script" >&2
        return 2
    fi

    local consensus_path
    consensus_path=$("$consensus_script" "$bold_output" "$critique_output" "$reducer_output" | tail -n 1)
    local consensus_exit=$?
    _planner_anim_stop

    if [ $consensus_exit -ne 0 ] || [ -z "$consensus_path" ]; then
        echo "Error: Consensus stage failed (exit code: $consensus_exit)" >&2
        return 2
    fi
    _planner_timer_log "consensus" "$t_consensus"

    _planner_log "$verbose" ""
    _planner_stage "Pipeline complete!"
    _planner_log "$verbose" "Consensus plan: $consensus_path"
    _planner_log "$verbose" ""

    # Publish to GitHub issue if in issue mode and issue number is available
    if [ "$issue_mode" = "true" ] && [ -n "$issue_number" ]; then
        _planner_stage "Publishing plan to issue #${issue_number}..."
        local plan_title
        plan_title=$(grep -m1 -E '^#[[:space:]]*(Implementation|Consensus) Plan:' "$consensus_path" \
            | sed -E 's/^#[[:space:]]*(Implementation|Consensus) Plan:[[:space:]]*//')
        [ -z "$plan_title" ] && plan_title="${feature_desc:0:50}"
        _planner_issue_publish "$issue_number" "$plan_title" "$consensus_path" || {
            echo "Warning: Failed to publish plan to issue #${issue_number}" >&2
        }
        # Print final issue link if URL is available
        if [ -n "${_PLANNER_ISSUE_URL:-}" ]; then
            term_label "See the full plan at:" "$_PLANNER_ISSUE_URL" "success"
        fi
    fi

    # Output consensus path to stdout
    echo "$consensus_path"
    return 0
}
