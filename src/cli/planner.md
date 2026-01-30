# planner.sh Interface Documentation

## Purpose

Internal loader for the planner pipeline module used by `lol plan`. Sources modular implementation files from `planner/` directory following the same source-first pattern as `acw.sh`, `wt.sh`, and `lol.sh`.

## Public Entry Point

```bash
lol plan [--dry-run] [--verbose] [--refine <issue-no> [refinement-instructions]] \
  "<feature-description>"
lol plan --refine <issue-no> [refinement-instructions]
```

This module exports only internal `_planner_*` helpers; the public entrypoint is `lol plan`.

## Backend Configuration (.agentize.local.yaml)

Planner reads per-stage backend overrides from `.agentize.local.yaml` using `provider:model` strings:

```yaml
planner:
  backend: claude:opus
  understander: claude:sonnet
  bold: claude:opus
  critique: claude:opus
  reducer: claude:opus
```

Stage-specific keys override `planner.backend`. Defaults are `claude:sonnet` for understander and `claude:opus` for bold/critique/reducer.

## Private Helpers

| Function | Location | Purpose |
|----------|----------|---------|
| `_planner_run_pipeline` | `planner/pipeline.sh` | Orchestrates the multi-agent debate pipeline (optional issue mode/refine) |
| `_planner_render_prompt` | `planner/pipeline.sh` | Concatenates agent prompt + plan-guideline + context into a temp file |
| `_planner_issue_create` | `planner/github.sh` | Creates placeholder GitHub issue (optional) |
| `_planner_issue_fetch` | `planner/github.sh` | Fetches existing issue body for refine mode |
| `_planner_issue_publish` | `planner/github.sh` | Updates issue body and adds `agentize:plan` label |

## Module Load Order

```
planner.sh           # Loader: determines script dir, sources modules
planner/pipeline.sh  # Multi-agent pipeline orchestration
planner/github.sh    # GitHub issue creation/update helpers
```

## Output Behavior

When stderr is a TTY, `lol plan` prints a colored "Feature:" label, per-stage animated dots, and per-agent elapsed time logs. Set `NO_COLOR=1` to disable color and `PLANNER_NO_ANIM=1` to disable animation.

## Design Rationale

The planner module separates pipeline logic from the `lol plan` entry point so that the pipeline internals (stage ordering, prompt rendering, parallelism) can evolve independently. The `_planner_render_prompt` helper centralizes prompt assembly to ensure consistent plan-guideline injection across all stages that require it.
