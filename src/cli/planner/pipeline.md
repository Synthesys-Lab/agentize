# pipeline.sh

Multi-agent planning pipeline orchestration for the CLI planner. This module is sourced by
`src/cli/planner.sh` and exposes pipeline entry points plus shared rendering helpers.

## External Interface

### _planner_run_pipeline "<feature-description>" [issue-mode] [verbose] [refine-issue-number] [pipeline-type]
Runs the full multi-stage planning pipeline driven by a YAML descriptor, followed by external consensus synthesis.

**Parameters**:
- `feature-description`: Request text or issue body used to build the prompts.
- `issue-mode`: `"true"` to create/publish to a GitHub issue when possible; `"false"` for timestamp-only artifacts.
- `verbose`: `"true"` to print detailed progress messages to stderr.
- `refine-issue-number`: Optional issue number to refine an existing plan; fetches the issue body and appends refinement focus.
- `pipeline-type`: Pipeline descriptor to use; `"ultra"` (default, 4-agent) or `"mega"` (5-agent dual-proposer).

**Behavior**:
- Loads pipeline descriptor from `src/cli/planner/pipelines/{pipeline-type}.yaml`.
- Creates stage artifacts under `.tmp/` using an issue-based or timestamp prefix.
- Loads planner backends from `.agentize.local.yaml` (planner.* keys) when present.
- Executes stages via `_planner_exec_pipeline`, then synthesizes a consensus plan via the external-consensus skill.
- Publishes the plan to the issue when `issue-mode` is true and an issue number is available.

**Output**:
- Prints stage progress and summary to stderr.
- Prints the consensus plan path via `term_label` to stdout.

**Exit codes**:
- `0`: Success.
- `1`: Configuration or setup failure (repo root/backends/pipeline descriptor).
- `2`: Pipeline stage failure (prompt render, agent run, or consensus synthesis).

### _planner_render_prompt <output-file> <agent-md-path> <include-plan-guideline> <feature-desc> [context-file...]
Builds a prompt file by concatenating the agent base prompt, optional plan-guideline, the feature request,
and optional context from previous stages (variadic).

**Parameters**:
- `output-file`: Path to write the rendered prompt.
- `agent-md-path`: Repo-relative path to the agent prompt markdown.
- `include-plan-guideline`: `"true"` to append the plan-guideline skill content.
- `feature-desc`: Feature request text inserted into the prompt.
- `context-file...`: Zero or more paths to append prior stage outputs. First file gets header "Previous Stage Output", subsequent files get "Additional Context (N)".

**Exit codes**:
- `0`: Success.
- `1`: Missing repo root or agent prompt file.

### _planner_exec_agent <name> <agent-md> <backend> <tools> <permission-mode> <plan-guideline> <input-path> <output-path> <feature-desc> [context-file...]
Executes a single agent stage by rendering the prompt and invoking acw.

**Parameters**:
- `name`: Agent identifier for error messages.
- `agent-md`: Repo-relative path to agent prompt markdown.
- `backend`: Backend spec in `provider:model` format.
- `tools`: Comma-separated tool list for acw.
- `permission-mode`: Optional permission mode (e.g., `"plan"`).
- `plan-guideline`: `"true"` to include plan-guideline in prompt.
- `input-path`: Path to write rendered prompt.
- `output-path`: Path for agent output.
- `feature-desc`: Feature request text.
- `context-file...`: Variadic context files from prior stages.

**Exit codes**:
- `0`: Success.
- `2`: Prompt rendering or agent execution failure.

### _planner_load_pipeline <yaml-path> <backend-overrides> [global-backend]
Parses a YAML pipeline descriptor and emits line-separated stage commands.

**Parameters**:
- `yaml-path`: Path to pipeline YAML file.
- `backend-overrides`: Newline-delimited `key=value` pairs for agent-specific backends.
- `global-backend`: Optional fallback backend for all agents.

**Output format**:
```
STAGE:<label>:<agent-count>
AGENT:<name>|<agent_md>|<backend>|<tools>|<permission>|<plan_guideline>|<inputs-comma-sep>
STAGE_END
```

**Exit codes**:
- `0`: Success.
- `1`: Pipeline file not found, invalid YAML, or missing required keys.

### _planner_exec_pipeline <pipeline-yaml> <prefix> <feature-desc> <backend-overrides> <global-backend> <verbose>
Executes a pipeline from a YAML descriptor, handling stage sequencing and parallel execution.

**Parameters**:
- `pipeline-yaml`: Path to pipeline YAML file.
- `prefix`: Artifact path prefix for stage inputs/outputs.
- `feature-desc`: Feature request text.
- `backend-overrides`: Newline-delimited backend overrides.
- `global-backend`: Fallback backend.
- `verbose`: `"true"` for detailed logging.

**Behavior**:
- Parses pipeline via `_planner_load_pipeline`.
- Executes agents sequentially within single-agent stages.
- Executes agents in parallel within multi-agent stages.
- Resolves input dependencies from prior agent outputs.

**Exit codes**:
- `0`: Success.
- `1`: Pipeline parsing failure.
- `2`: Agent execution failure.

## Internal Helpers

### _planner_color_enabled / _planner_anim_enabled
Checks whether colored output or animation is enabled on stderr based on environment flags and TTY state.

### _planner_print_feature
Prints a styled "Feature:" label and description using `term_label`.

### _planner_timer_start / _planner_timer_log
Tracks stage timings using epoch seconds and logs elapsed durations.

### _planner_anim_start / _planner_anim_stop
Manages a simple dot animation on stderr to show stage progress.

### _planner_print_issue_created
Prints a styled "issue created" message using `term_label`.

### _planner_validate_backend
Validates backend specs in `provider:model` format; emits errors for invalid inputs.

### _planner_load_backend_config
Loads `planner.*` backend overrides from `.agentize.local.yaml` via helper module
`lib/local_config_io` with a Python fallback parser.

### _planner_acw_run
Runs `acw` with provider/model and optional Claude-only flags (tools/permission mode).

### _planner_log / _planner_stage
Logging helpers for verbose and stage-specific stderr output.
