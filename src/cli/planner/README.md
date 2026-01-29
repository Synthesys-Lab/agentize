# planner CLI Module Map

## Purpose

Internal pipeline module used by `lol plan`; the standalone `planner` command has been removed.

## Contents

```
planner.sh           - Loader: determines script dir, sources modules
planner/pipeline.sh  - Multi-agent pipeline orchestration + status rendering (timing, animation; styling via term helpers)
planner/github.sh    - GitHub issue creation/update helpers
```

## Load Order

1. `pipeline.sh` - Defines `_planner_run_pipeline()` and `_planner_render_prompt()` helpers
2. `github.sh` - Defines `_planner_issue_create()`, `_planner_issue_fetch()`, and `_planner_issue_publish()` helpers

## Related Documentation

- [src/cli/planner.md](../planner.md) - Interface documentation
- [docs/cli/planner.md](../../../docs/cli/planner.md) - User-facing pipeline reference
