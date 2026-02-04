# __main__.py

CLI backend for `python -m agentize.workflow.planner`, delegating pipeline execution to `pipeline.py`.

## External Interfaces

### `main()`

```python
def main(argv: list[str]) -> int
```

CLI entrypoint for the planner backend. Parses args, resolves repo root and backend
configuration, runs stages, publishes plan updates with a trailing commit provenance
footer (when enabled), and prints plain-text progress output. Refinement fetches strip
the footer before reuse as debate context. Returns process exit code.

## Internal Helpers

### Stage execution

The CLI delegates stage execution to `pipeline.run_planner_pipeline()` and
`pipeline.run_consensus_stage()`, which use the Session DSL and the workflow API
helpers for prompt rendering and ACW invocation.

### Issue/publish helpers

- `_issue_create()`, `_issue_fetch()`, `_issue_publish()`: GitHub issue lifecycle for
  plan publishing backed by `agentize.workflow.api.gh`.
- `_extract_plan_title()`, `_apply_issue_tag()`: Plan title parsing and issue tagging.
- `_resolve_commit_hash()`: Resolves the current repo `HEAD` commit for provenance.
- `_append_plan_footer()`: Appends `Plan based on commit <hash>` to consensus output.
- `_strip_plan_footer()`: Removes the trailing provenance footer from issue bodies.

### Backend selection

- `_load_planner_backend_config()`, `_resolve_stage_backends()`: Reads
  `.agentize.local.yaml` and resolves provider/model pairs per stage.

## Design Rationale

- **Pipeline separation**: CLI orchestration lives here while the Session-based pipeline
  stays in `pipeline.py`.
- **Plain progress output**: The CLI prints concise stage lines without TTY-specific
  rendering to keep logs readable in terminals and CI.
- **Isolation**: Issue/publish logic is kept in helpers to reduce coupling between CLI
  glue and workflow execution.
