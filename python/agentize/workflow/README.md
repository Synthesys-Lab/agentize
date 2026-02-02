# Workflow Module

Python-native orchestration for multi-stage LLM planner workflows.

## Purpose

This module provides a Python entrypoint for running the planner flow that powers `lol plan`. It reuses established prompt templates from `.claude-plugin/agents/` to maintain behavioral consistency while enabling Python scripting integration and external consensus synthesis.

## Architecture

The workflow module wraps the `acw` shell function (Agentize Claude Wrapper) to execute each pipeline stage. Prompts are rendered by combining:

1. Base agent prompts from `.claude-plugin/agents/*.md`
2. Plan-guideline content from `.claude-plugin/skills/plan-guideline/SKILL.md` (for applicable stages)
3. Feature description provided by the caller
4. Previous stage output (for chained stages)

Artifacts (input prompts and outputs) are written to `.tmp/` with a configurable prefix and output suffix.

## Modules

| Module | Purpose |
|--------|---------|
| `__init__.py` | Package exports: `run_acw`, `run_planner_pipeline`, `StageResult`, `PlannerTTY` |
| `utils.py` | Reusable TTY and shell invocation utilities |
| `planner/` | Standalone planning pipeline package (`python -m agentize.workflow.planner`) |
| `planner.py` | **DEPRECATED** - Re-exports for backward compatibility (will be removed) |

## Pipeline Stages

```
understander → bold → critique → reducer → consensus (optional)
                      ↓           ↓
                    (parallel when enabled)
```

1. **Understander**: Gathers codebase context and constraints
2. **Bold**: Proposes innovative implementation approaches
3. **Critique**: Validates assumptions and analyzes feasibility
4. **Reducer**: Simplifies proposals following "less is more" philosophy
5. **Consensus**: Synthesizes a unified implementation plan (optional for library use; CLI delegates to the external consensus script)

## Usage

```python
from agentize.workflow import run_planner_pipeline

results = run_planner_pipeline(
    "Add user authentication with JWT tokens",
    output_dir=".tmp",
    parallel=True,
    output_suffix=".txt",
    skip_consensus=True,
)

# Access per-stage results
for stage, result in results.items():
    print(f"{stage}: {result.output_path}")
```

## Dependencies

- `acw` shell function via `setup.sh`
- Prompt templates in `.claude-plugin/agents/` and `.claude-plugin/skills/`
- Python stdlib only (no third-party dependencies)
