# Planner Pipeline

Python implementation of the multi-stage planner workflow and CLI backend used by `lol plan`.

## Purpose

Provide a Python-native pipeline runner that reuses existing prompt templates, preserves artifact naming, and supports the external consensus synthesis step required by the CLI planner.

## External Interface

### `run_acw(provider, model, input_file, output_file, *, tools=None, permission_mode=None, extra_flags=None, timeout=900) -> subprocess.CompletedProcess`

Runs the `acw` shell wrapper with quoted arguments and optional Claude-specific flags.

**Parameters:**
- `provider`: Backend provider (e.g., `"claude"`, `"codex"`)
- `model`: Model identifier (e.g., `"sonnet"`, `"opus"`)
- `input_file`: Path to input prompt file
- `output_file`: Path for stage output
- `tools`: Tool configuration (Claude provider only)
- `permission_mode`: Permission mode override (Claude provider only)
- `extra_flags`: Additional CLI flags
- `timeout`: Execution timeout in seconds

### `run_planner_pipeline(feature_desc, *, output_dir=".tmp", backends=None, parallel=True, runner=run_acw, prefix=None, output_suffix="-output.md", skip_consensus=False, progress=None) -> dict[str, StageResult]`

Executes the planner stages (understander → bold → critique → reducer → consensus) and returns per-stage results.

**Parameters:**
- `feature_desc`: Feature request description to plan
- `output_dir`: Directory for artifacts
- `backends`: Mapping of stage names to `(provider, model)` tuples
- `parallel`: Run critique and reducer in parallel
- `runner`: Callable used to invoke each stage (injectable for tests)
- `prefix`: Artifact filename prefix (defaults to timestamp)
- `output_suffix`: Suffix appended to stage output files (e.g., `.txt`)
- `skip_consensus`: Skip the consensus stage when external synthesis is used
- `progress`: Optional `PlannerTTY` for stage logs/animation

**Returns:** Dict mapping stage names to `StageResult` objects.

**Raises:**
- `FileNotFoundError` when required prompt templates are missing
- `RuntimeError` when a stage fails or produces empty output

### `main(argv: list[str]) -> int`

CLI entrypoint used by `lol plan`. It orchestrates:
1. Repo root resolution and `.tmp` output setup
2. Planner backend config loading from `.agentize.local.yaml`
3. Issue refinement and placeholder creation (when enabled)
4. Stages 1–4 via `run_planner_pipeline(..., output_suffix=".txt", skip_consensus=True)`
5. External consensus synthesis via `external-consensus.sh`
6. Issue publish (title extraction + label application)
7. Final output paths and optional issue link rendering

**CLI arguments:**
- `--feature-desc`: Feature description or refine focus
- `--issue-mode`: `true` or `false`
- `--verbose`: `true` or `false`
- `--refine-issue-number`: Issue number to refine (optional)

## Pipeline Flow

```
understander → bold → critique → reducer → consensus (optional)
                        ↓         ↓
                    (parallel when enabled)
```

`skip_consensus=True` allows the CLI to delegate Stage 5 to the external consensus script while still using the same prompt rendering for stages 1–4.

## Artifact Layout

Stage input prompts are written as `{prefix}-{stage}-input.md` and outputs follow `{prefix}-{stage}{output_suffix}`.

Example with `.txt` output suffix:

```
.tmp/issue-123-understander-input.md
.tmp/issue-123-understander.txt
.tmp/issue-123-bold-input.md
.tmp/issue-123-bold.txt
.tmp/issue-123-critique-input.md
.tmp/issue-123-critique.txt
.tmp/issue-123-reducer-input.md
.tmp/issue-123-reducer.txt
```

The external consensus step produces the final `.md` plan file.

## Internal Helpers

### `PlannerTTY`
Formats stage labels, dot animations, and timing logs with the same environment gates as the shell planner (`NO_COLOR`, `PLANNER_NO_COLOR`, `PLANNER_NO_ANIM`).

### `_load_planner_backend_config()`
Loads `planner.*` overrides from `.agentize.local.yaml` via shared YAML helpers.

### `_resolve_stage_backends()`
Normalizes backend defaults (sonnet for understander, opus for the rest) and validates `provider:model` format.

### `_run_external_consensus()`
Invokes the external consensus script and returns the consensus file path.

### `_issue_create()` / `_issue_fetch()` / `_issue_publish()`
Wraps `gh` issue operations for placeholder creation, refinement context, and plan publishing.

## Design Rationale

- **Output suffix control:** Keeps legacy artifact naming for CLI workflows while retaining the default `-output.md` format for library usage.
- **Consensus delegation:** Supports the external consensus script as the canonical synthesis stage without duplicating its validation logic.
- **TTY parity:** Mirrors the shell pipeline’s visual feedback without introducing optional dependencies.
- **Shared config loading:** Reuses `.agentize.local.yaml` discovery to keep planner backends consistent across workflows.
