# pipeline.sh

Thin adapter that forwards `lol plan` execution to the Python planner backend. This module is sourced by
`src/cli/planner.sh` and exposes the same `_planner_run_pipeline` entrypoint expected by the CLI.

## External Interface

### _planner_run_pipeline "<feature-description>" [issue-mode] [verbose] [refine-issue-number]

Delegates to `python -m agentize.workflow.planner` with the provided arguments.

**Parameters**:
- `feature-description`: Request text or refinement focus forwarded to the Python backend.
- `issue-mode`: `"true"` to create/publish to a GitHub issue when possible; `"false"` for timestamp-only artifacts.
- `verbose`: `"true"` to print detailed progress messages to stderr.
- `refine-issue-number`: Optional issue number to refine an existing plan.

**Behavior**:
- Resolves repo root and sets `AGENTIZE_HOME` and `PYTHONPATH` for Python imports.
- Invokes the Python planner CLI backend which handles config loading, stage execution, and consensus synthesis.

**Output**:
- Emits the same stage logs, timing lines, and final plan paths as the Python backend.

**Exit codes**:
- `0`: Success.
- `1`: Configuration or setup failure (repo root/config/issue fetch).
- `2`: Pipeline stage failure (agent run or consensus synthesis).

## Internal Helpers

This adapter keeps no internal helper functions beyond `_planner_run_pipeline`; all planner orchestration
lives in the Python backend.
