# planner.sh Interface Documentation

## Purpose

Thin loader for the planner CLI module. Sources modular implementation files from `planner/` directory following the same source-first pattern as `acw.sh`, `wt.sh`, and `lol.sh`. The preferred entrypoint is `lol plan`; `planner` is retained as a legacy alias.

## Public Entry Point

```bash
lol plan [--dry-run] [--verbose] "<feature-description>"
planner plan [--dry-run] [--verbose] "<feature-description>"  # legacy alias
planner --help
```

`planner` is the only public function exported by this module. `lol plan` delegates to the same `_planner_run_pipeline` function.

## Private Helpers

| Function | Location | Purpose |
|----------|----------|---------|
| `_planner_run_pipeline` | `planner/pipeline.sh` | Orchestrates the multi-agent debate pipeline (optional issue mode) |
| `_planner_render_prompt` | `planner/pipeline.sh` | Concatenates agent prompt + plan-guideline + context into a temp file |
| `_planner_issue_create` | `planner/github.sh` | Creates placeholder GitHub issue (optional) |
| `_planner_issue_publish` | `planner/github.sh` | Updates issue body and adds `agentize:plan` label |

## Module Load Order

```
planner.sh           # Loader: determines script dir, sources modules
planner/dispatch.sh  # Main dispatcher and help text
planner/pipeline.sh  # Multi-agent pipeline orchestration
planner/github.sh    # GitHub issue creation/update helpers
```

## Output Behavior

When stderr is a TTY, `planner plan` prints a colored "Feature:" label, per-stage animated dots, and per-agent elapsed time logs. Set `NO_COLOR=1` to disable color and `PLANNER_NO_ANIM=1` to disable animation.

## Design Rationale

The planner CLI separates dispatch from pipeline logic so that the public interface (`planner plan`) remains stable while pipeline internals (stage ordering, prompt rendering, parallelism) can evolve independently. The `_planner_render_prompt` helper centralizes prompt assembly to ensure consistent plan-guideline injection across all stages that require it.
