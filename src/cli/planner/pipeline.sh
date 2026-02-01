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

# Render a prompt by concatenating agent base prompt, optional plan-guideline, feature desc, and context files
# Usage: _planner_render_prompt <output-file> <agent-md-path> <include-plan-guideline> <feature-desc> [context-file...]
_planner_render_prompt() {
    local output_file="$1"
    local agent_md="$2"
    local include_plan_guideline="$3"
    local feature_desc="$4"
    shift 4
    local -a context_files=("$@")

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

    # Append context from previous stages (variadic)
    local context_idx=0
    for context_file in "${context_files[@]}"; do
        if [ -n "$context_file" ] && [ -f "$context_file" ]; then
            echo "" >> "$output_file"
            echo "---" >> "$output_file"
            echo "" >> "$output_file"
            if [ $context_idx -eq 0 ]; then
                echo "# Previous Stage Output" >> "$output_file"
            else
                echo "# Additional Context ($((context_idx + 1)))" >> "$output_file"
            fi
            echo "" >> "$output_file"
            cat "$context_file" >> "$output_file"
            context_idx=$((context_idx + 1))
        fi
    done
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

# Execute a single agent stage
# Usage: _planner_exec_agent <name> <agent-md> <backend> <tools> <permission-mode> <plan-guideline> <input-path> <output-path> <feature-desc> [context-file...]
_planner_exec_agent() {
    local name="$1"
    local agent_md="$2"
    local backend="$3"
    local tools="$4"
    local permission_mode="$5"
    local plan_guideline="$6"
    local input_path="$7"
    local output_path="$8"
    local feature_desc="$9"
    shift 9
    local -a context_files=("$@")

    # Render prompt with multiple context files
    if ! _planner_render_prompt "$input_path" "$agent_md" "$plan_guideline" "$feature_desc" "${context_files[@]}"; then
        echo "Error: ${name} prompt rendering failed" >&2
        return 2
    fi

    # Execute agent via acw
    _planner_acw_run "$backend" "$input_path" "$output_path" "$tools" "$permission_mode"
    local exit_code=$?

    if [ $exit_code -ne 0 ] || [ ! -s "$output_path" ]; then
        echo "Error: ${name} stage failed (exit code: $exit_code)" >&2
        return 2
    fi

    return 0
}

# Load and parse pipeline descriptor from YAML file
# Usage: _planner_load_pipeline <yaml-path> <backend-overrides> [global-backend]
# Outputs: Line-separated stage commands in format:
#   STAGE:<label>:<parallel-agent-count>
#   AGENT:<name>|<agent_md>|<backend>|<tools>|<permission>|<plan_guideline>|<inputs-comma-sep>
#   STAGE_END
_planner_load_pipeline() {
    local yaml_path="$1"
    local backend_overrides="$2"
    local global_backend="${3:-}"
    local repo_root="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"

    PIPELINE_YAML_PATH="$yaml_path" \
    PIPELINE_BACKENDS="$backend_overrides" \
    PIPELINE_GLOBAL_BACKEND="$global_backend" \
    PIPELINE_REPO_ROOT="$repo_root" \
    python3 - <<'PY'
import os
import sys
from pathlib import Path

yaml_path = Path(os.environ.get("PIPELINE_YAML_PATH", ""))
backend_overrides_str = os.environ.get("PIPELINE_BACKENDS", "")
global_backend = os.environ.get("PIPELINE_GLOBAL_BACKEND", "")
repo_root = Path(os.environ.get("PIPELINE_REPO_ROOT", "."))

if not yaml_path.is_file():
    print(f"Error: Pipeline file not found: {yaml_path}", file=sys.stderr)
    sys.exit(1)

# Parse backend overrides
overrides = {}
for line in backend_overrides_str.strip().split("\n"):
    if "=" in line:
        k, v = line.split("=", 1)
        overrides[k.strip()] = v.strip()

# Parse YAML
try:
    import yaml
    with open(yaml_path) as f:
        data = yaml.safe_load(f)
except ImportError:
    # Fallback to local_config_io
    plugin_dir = repo_root / ".claude-plugin"
    if plugin_dir.is_dir():
        sys.path.insert(0, str(plugin_dir))
    try:
        from lib.local_config_io import parse_yaml_file
        data = parse_yaml_file(yaml_path)
    except ImportError:
        print("Error: Neither PyYAML nor local_config_io available", file=sys.stderr)
        sys.exit(1)

if not isinstance(data, dict) or "stages" not in data:
    print("Error: Pipeline must have 'stages' key", file=sys.stderr)
    sys.exit(1)

for stage in data["stages"]:
    label = stage.get("label", stage.get("name", "unknown"))
    agents = stage.get("agents", [])
    print(f"STAGE:{label}:{len(agents)}")

    for agent in agents:
        name = agent.get("name", "unknown")
        agent_md = agent.get("agent_md", "")
        if not agent_md:
            print(f"Error: Agent '{name}' missing agent_md path", file=sys.stderr)
            sys.exit(1)
        backend_key = agent.get("backend_key", name)
        default_backend = agent.get("default_backend", "claude:opus")
        tools = agent.get("tools", "Read,Grep,Glob")
        permission = agent.get("permission_mode", "")
        plan_guideline = "true" if agent.get("plan_guideline", False) else "false"
        inputs = ",".join(agent.get("inputs", []))

        # Resolve backend: override > global > default
        backend = overrides.get(backend_key) or global_backend or default_backend

        print(f"AGENT:{name}|{agent_md}|{backend}|{tools}|{permission}|{plan_guideline}|{inputs}")

    print("STAGE_END")
PY
}

# Execute pipeline from parsed stage commands
# Usage: _planner_exec_pipeline <pipeline-yaml> <prefix> <feature-desc> <backend-overrides> <global-backend> <verbose>
_planner_exec_pipeline() {
    local pipeline_yaml="$1"
    local prefix="$2"
    local feature_desc="$3"
    local backend_overrides="$4"
    local global_backend="$5"
    local verbose="$6"

    # Get parsed commands from Python
    local commands
    commands=$(_planner_load_pipeline "$pipeline_yaml" "$backend_overrides" "$global_backend") || {
        echo "Error: Pipeline parsing failed" >&2
        return 1
    }

    local stage_count=0

    # Track agent outputs for input resolution
    declare -A agent_outputs

    local current_label=""
    local agents_in_stage=0
    local -a pids=()
    local -a agent_names=()
    local -a agent_output_paths=()
    local t_stage

    while IFS= read -r line; do
        case "$line" in
            STAGE:*)
                # Parse: STAGE:<label>:<agent_count>
                local stage_info="${line#STAGE:}"
                current_label="${stage_info%:*}"
                agents_in_stage="${stage_info##*:}"
                stage_count=$((stage_count + 1))
                t_stage=$(_planner_timer_start)
                pids=()
                agent_names=()
                agent_output_paths=()
                _planner_anim_start "$current_label"
                ;;

            AGENT:*)
                # Parse: AGENT:<name>|<agent_md>|<backend>|<tools>|<permission>|<plan_guideline>|<inputs>
                local agent_line="${line#AGENT:}"
                IFS='|' read -r name agent_md backend tools permission plan_guideline inputs_str <<< "$agent_line"

                local input_path="${prefix}-${name}-input.md"
                local output_path="${prefix}-${name}.txt"

                agent_names+=("$name")
                agent_output_paths+=("$output_path")

                # Resolve input files from previous agent outputs
                local -a context_files=()
                if [ -n "$inputs_str" ]; then
                    IFS=',' read -ra input_names <<< "$inputs_str"
                    for input_name in "${input_names[@]}"; do
                        if [ -n "${agent_outputs[$input_name]:-}" ]; then
                            context_files+=("${agent_outputs[$input_name]}")
                        fi
                    done
                fi

                if [ "$agents_in_stage" -eq 1 ]; then
                    # Sequential execution
                    _planner_exec_agent "$name" "$agent_md" "$backend" "$tools" "$permission" "$plan_guideline" \
                        "$input_path" "$output_path" "$feature_desc" "${context_files[@]}"
                    local exit_code=$?
                    _planner_anim_stop
                    if [ $exit_code -ne 0 ]; then
                        return $exit_code
                    fi
                    _planner_timer_log "$name" "$t_stage"
                    _planner_log "$verbose" "  ${name} complete: $output_path"
                else
                    # Parallel execution
                    _planner_exec_agent "$name" "$agent_md" "$backend" "$tools" "$permission" "$plan_guideline" \
                        "$input_path" "$output_path" "$feature_desc" "${context_files[@]}" &
                    pids+=($!)
                fi
                ;;

            STAGE_END)
                # Wait for parallel agents
                if [ "$agents_in_stage" -gt 1 ] && [ ${#pids[@]} -gt 0 ]; then
                    local all_success=true
                    for i in "${!pids[@]}"; do
                        wait "${pids[$i]}" || all_success=false
                        local aout="${agent_output_paths[$i]}"
                        if [ ! -s "$aout" ]; then
                            all_success=false
                        fi
                    done
                    _planner_anim_stop
                    if [ "$all_success" != "true" ]; then
                        echo "Error: One or more agents in stage failed" >&2
                        return 2
                    fi
                    _planner_timer_log "${current_label}" "$t_stage"
                    for i in "${!agent_names[@]}"; do
                        _planner_log "$verbose" "  ${agent_names[$i]} complete: ${agent_output_paths[$i]}"
                    done
                fi

                # Record outputs for downstream input resolution
                for i in "${!agent_names[@]}"; do
                    agent_outputs["${agent_names[$i]}"]="${agent_output_paths[$i]}"
                done
                _planner_log "$verbose" ""
                ;;
        esac
    done <<< "$commands"

    return 0
}

# Run the full multi-agent debate pipeline
# Usage: _planner_run_pipeline "<feature-description>" [issue-mode] [verbose] [refine-issue-number] [pipeline-type]
# pipeline-type: "ultra" (default) or "mega"
_planner_run_pipeline() {
    local feature_desc="$1"
    local issue_mode="${2:-true}"
    local verbose="${3:-false}"
    local refine_issue_number="${4:-}"
    local pipeline_type="${5:-ultra}"
    local repo_root="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    if [ -z "$repo_root" ] || [ ! -d "$repo_root" ]; then
        echo "Error: Could not determine repo root. Set AGENTIZE_HOME or run inside a git repo." >&2
        return 1
    fi

    # Select pipeline YAML
    local pipeline_yaml="$repo_root/src/cli/planner/pipelines/${pipeline_type}.yaml"
    if [ ! -f "$pipeline_yaml" ]; then
        echo "Error: Pipeline descriptor not found: $pipeline_yaml" >&2
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

    # Load backend configuration
    local config_start_dir="${PWD:-$(pwd)}"
    local global_backend=""
    local backend_overrides=""
    local backend_config
    backend_config=$(_planner_load_backend_config "$repo_root" "$config_start_dir") || return 1
    if [ -n "$backend_config" ]; then
        while IFS='=' read -r key value; do
            if [ "$key" = "backend" ]; then
                global_backend="$value"
            else
                backend_overrides="${backend_overrides}${key}=${value}"$'\n'
            fi
        done <<< "$backend_config"
    fi

    # Validate global backend if set
    if ! _planner_validate_backend "$global_backend" "planner.backend"; then
        return 1
    fi

    _planner_stage "Starting multi-agent debate pipeline..."
    _planner_print_feature "$feature_desc"
    _planner_log "$verbose" "Artifacts prefix: ${prefix_name}"
    _planner_log "$verbose" "Pipeline: ${pipeline_type}"
    _planner_log "$verbose" ""

    # Execute pipeline from YAML descriptor
    if ! _planner_exec_pipeline "$pipeline_yaml" "$prefix" "$feature_desc" "$backend_overrides" "$global_backend" "$verbose"; then
        return 2
    fi

    # ── Final Stage: External Consensus ──
    # (Kept as special post-pipeline step - not part of YAML descriptor)
    local t_consensus
    t_consensus=$(_planner_timer_start)
    _planner_anim_start "Final Stage: Running external consensus synthesis"

    local consensus_script="${_PLANNER_CONSENSUS_SCRIPT:-$repo_root/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh}"

    if [ ! -f "$consensus_script" ]; then
        _planner_anim_stop
        echo "Error: Consensus script not found: $consensus_script" >&2
        return 2
    fi

    # Get output paths for consensus inputs based on pipeline type
    local bold_output="${prefix}-bold.txt"
    local critique_output="${prefix}-critique.txt"
    local reducer_output="${prefix}-reducer.txt"
    local -a consensus_inputs=("$bold_output" "$critique_output" "$reducer_output")

    if [ "$pipeline_type" = "mega" ]; then
        local paranoia_output="${prefix}-paranoia.txt"
        local code_reducer_output="${prefix}-code-reducer.txt"
        consensus_inputs=("$bold_output" "$paranoia_output" "$critique_output" "$reducer_output" "$code_reducer_output")
    fi

    local consensus_path
    consensus_path=$("$consensus_script" "${consensus_inputs[@]}" | tail -n 1)
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
        local issue_tag="[#${issue_number}]"
        case "$plan_title" in
            "${issue_tag}"|"$issue_tag "*)
                ;;
            *)
                if [ -n "$plan_title" ]; then
                    plan_title="${issue_tag} ${plan_title}"
                else
                    plan_title="${issue_tag}"
                fi
                ;;
        esac
        _planner_issue_publish "$issue_number" "$plan_title" "$consensus_path" || {
            echo "Warning: Failed to publish plan to issue #${issue_number}" >&2
        }
        # Print final issue link if URL is available
        if [ -n "${_PLANNER_ISSUE_URL:-}" ]; then
            term_label "See the full plan at:" "$_PLANNER_ISSUE_URL" "success"
        fi
    fi

    # Output consensus path to stdout
    term_label "See the full plan locally at:" "$consensus_path"
    return 0
}
