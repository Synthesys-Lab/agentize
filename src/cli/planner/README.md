# planner CLI Module Map

## Purpose

Modular implementation of the `planner` CLI command for running the multi-agent debate pipeline from the shell.

## Contents

```
planner.sh           - Loader: determines script dir, sources modules
planner/dispatch.sh  - Main dispatcher and help text
planner/pipeline.sh  - Multi-agent pipeline orchestration
planner/github.sh    - GitHub issue creation/update helpers
```

## Load Order

1. `dispatch.sh` - Defines `planner()` entry point and `_planner_usage()` help text
2. `pipeline.sh` - Defines `_planner_run_pipeline()` and `_planner_render_prompt()` helpers
3. `github.sh` - Defines `_planner_issue_create()` and `_planner_issue_publish()` helpers

## Related Documentation

- [src/cli/planner.md](../planner.md) - Interface documentation
- [docs/cli/planner.md](../../../docs/cli/planner.md) - User-facing CLI reference
