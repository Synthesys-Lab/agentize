# planner.sh Interface Documentation

## Purpose

Thin loader for the planner CLI module. Sources modular implementation files from `planner/` directory following the same source-first pattern as `acw.sh`, `wt.sh`, and `lol.sh`.

## Public Entry Point

```bash
planner plan "<feature-description>"
planner --help
```

`planner` is the only public function exported by this module.

## Private Helpers

| Function | Location | Purpose |
|----------|----------|---------|
| `_planner_run_pipeline` | `planner/pipeline.sh` | Orchestrates the multi-agent debate pipeline |
| `_planner_render_prompt` | `planner/pipeline.sh` | Concatenates agent prompt + plan-guideline + context into a temp file |

## Module Load Order

```
planner.sh           # Loader: determines script dir, sources modules
planner/dispatch.sh  # Main dispatcher and help text
planner/pipeline.sh  # Multi-agent pipeline orchestration
```

## Design Rationale

The planner CLI separates dispatch from pipeline logic so that the public interface (`planner plan`) remains stable while pipeline internals (stage ordering, prompt rendering, parallelism) can evolve independently. The `_planner_render_prompt` helper centralizes prompt assembly to ensure consistent plan-guideline injection across all stages that require it.
