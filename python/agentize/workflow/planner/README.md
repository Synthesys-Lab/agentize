# Planner Package

Runnable package for the multi-stage planner pipeline. Provides both library interface and CLI entry point.

## Purpose

This package contains the 5-stage planner pipeline (understander → bold → critique → reducer → consensus) that powers `lol plan`. It is structured as a runnable package to support `python -m agentize.workflow.planner` invocation.

## Invocation

### As CLI

```bash
python -m agentize.workflow.planner --feature-desc "Add dark mode toggle" --issue-mode true
```

**Arguments:**
- `--feature-desc`: Feature description or refinement focus
- `--issue-mode`: `true` or `false` (create/update GitHub issue)
- `--verbose`: `true` or `false`
- `--refine-issue-number`: Issue number to refine (optional)

### As Library

```python
from agentize.workflow.planner import run_planner_pipeline, StageResult

results = run_planner_pipeline(
    "Implement JWT authentication",
    output_dir=".tmp",
    parallel=True,
)

for stage, result in results.items():
    print(f"{stage}: {result.output_path}")
```

## Module Structure

| File | Purpose |
|------|---------|
| `__init__.py` | Package exports: `run_planner_pipeline`, `StageResult`, `PlannerTTY` |
| `__main__.py` | Pipeline logic, CLI backend, and entry point |
| `README.md` | This documentation |

## Exports

- `run_planner_pipeline`: Execute the 5-stage pipeline
- `StageResult`: Dataclass for per-stage results
- `PlannerTTY`: Re-exported from `agentize.workflow.utils` for convenience

## Dependencies

- `agentize.workflow.utils`: TTY helpers and `run_acw` function
- `agentize.shell`: `get_agentize_home()` for path resolution
- Prompt templates in `.claude-plugin/agents/` and `.claude-plugin/skills/`

## Design Rationale

- **Runnable package**: Using `__main__.py` enables `python -m` invocation while keeping logic in a single file.
- **Re-exports**: `PlannerTTY` is re-exported for backward compatibility with code that imported it from the planner module.
- **Separation**: TTY/shell utilities live in `workflow/utils.py`; pipeline orchestration lives here.
