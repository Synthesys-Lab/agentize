# Planner Package

Runnable package for the multi-stage planner pipeline. Provides both library interface and CLI entry point.

## Purpose

This package contains the 5-stage planner pipeline (understander → bold → critique → reducer → consensus) that powers `lol plan`. Critique and reducer are always executed in parallel. It is structured as a runnable package to support `python -m agentize.workflow.planner` invocation, with the pipeline implemented as a Session DSL example.

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
)

for stage, result in results.items():
    print(f"{stage}: {result.output_path}")
```

## Module Structure

| File | Purpose |
|------|---------|
| `__init__.py` | Package exports: `run_planner_pipeline`, `StageResult` |
| `pipeline.py` | Planner pipeline implemented with the Session DSL |
| `__main__.py` | CLI backend and entry point |
| `README.md` | This documentation |

## Exports

- `run_planner_pipeline`: Execute the 5-stage pipeline
- `StageResult`: Dataclass for per-stage results

## Dependencies

- `agentize.workflow.api`: Session DSL, ACW runner, prompt rendering, and GitHub helpers
- `agentize.shell`: `get_agentize_home()` for path resolution
- Prompt templates in `.claude-plugin/agents/` and `.claude-plugin/skills/`

## Design Rationale

- **Runnable package**: Using `__main__.py` enables `python -m` invocation while keeping logic in a single file.
- **Separation**: Workflow helpers live in `workflow/api/`; pipeline orchestration lives here.
