# planner.sh Interface Documentation

## Purpose

Internal loader for the planner pipeline adapter used by `lol plan`. Sources modular implementation files from the `planner/` directory following the same source-first pattern as `acw.sh`, `wt.sh`, and `lol.sh` while delegating orchestration to the Python backend.

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
| `_planner_run_pipeline` | `planner/pipeline.sh` | Forwards planner execution to the Python backend |
| `_planner_issue_create` | `planner/github.sh` | Legacy GitHub helper (not used by adapter) |
| `_planner_issue_fetch` | `planner/github.sh` | Legacy GitHub helper (not used by adapter) |
| `_planner_issue_publish` | `planner/github.sh` | Legacy GitHub helper (not used by adapter) |

## Module Load Order

```
planner.sh           # Loader: determines script dir, sources modules
planner/pipeline.sh  # Python backend adapter
planner/github.sh    # Legacy GitHub helpers
```

## Output Behavior

The Python backend prints plain-text progress to stderr, including pipeline start, stage progress lines, and final artifact locations. Per-agent elapsed time logs are emitted by the `ACW` class when the default `acw` runner is used.

## Design Rationale

The adapter preserves the `lol plan` shell interface while consolidating pipeline orchestration, consensus synthesis, and issue publishing in Python for easier testing and reuse.
