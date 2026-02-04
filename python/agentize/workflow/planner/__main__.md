# __main__.py

Planner pipeline orchestration and CLI backend for `python -m agentize.workflow.planner`.

## External Interfaces

### `StageResult`

```python
@dataclass
class StageResult:
    stage: str
    input_path: Path
    output_path: Path
    process: subprocess.CompletedProcess
```

Represents a single stage execution result, including the input/output artifact paths and
subprocess result.

### `run_planner_pipeline()`

```python
def run_planner_pipeline(
    feature_desc: str,
    *,
    output_dir: str | Path = ".tmp",
    backends: dict[str, tuple[str, str]] | None = None,
    parallel: bool = True,
    runner: Callable[..., subprocess.CompletedProcess] = run_acw,
    prefix: str | None = None,
    output_suffix: str = "-output.md",
    skip_consensus: bool = False,
) -> dict[str, StageResult]
```

Executes the 5-stage planner pipeline. Stages run through the `ACW` class (provider
validation + start/finish timing logs). The pipeline prints plain stage-start lines to
stderr and returns `StageResult` objects for each stage.

### `main()`

```python
def main(argv: list[str]) -> int
```

CLI entrypoint for the planner backend. Parses args, resolves repo root and backend
configuration, runs stages, publishes plan updates with a trailing commit provenance
footer (when enabled), and prints plain-text progress output. Refinement fetches strip
the footer before reuse as debate context. Returns process exit code.

## Internal Helpers

### Prompt rendering

- `_render_stage_prompt()`: Builds each stage prompt from agent template, plan-guideline
  content, feature description, and previous outputs.
- `_render_consensus_prompt()`: Builds the consensus prompt by embedding bold/critique/
  reducer outputs into the external-consensus template.

### Stage execution

- `_run_consensus_stage()`: Runs the consensus stage and returns a `StageResult`.
  Uses `ACW` when the default `run_acw` runner is in use, accepting an optional
  `log_writer` for serialized log output.

### Issue/publish helpers

- `_issue_create()`, `_issue_fetch()`, `_issue_publish()`: GitHub issue lifecycle for
  plan publishing.
- `_extract_plan_title()`, `_apply_issue_tag()`: Plan title parsing and issue tagging.
- `_resolve_commit_hash()`: Resolves the current repo `HEAD` commit for provenance.
- `_append_plan_footer()`: Appends `Plan based on commit <hash>` to consensus output.
- `_strip_plan_footer()`: Removes the trailing provenance footer from issue bodies.

### Backend selection

- `_load_planner_backend_config()`, `_resolve_stage_backends()`: Reads
  `.agentize.local.yaml` and resolves provider/model pairs per stage.

## Design Rationale

- **Unified runner path**: The pipeline uses the `ACW` class for stage execution so
  timing logs and provider validation remain consistent.
- **Plain progress output**: The CLI prints concise stage lines without TTY-specific
  rendering to keep logs readable in terminals and CI.
- **Isolation**: Prompt rendering and issue/publish logic are kept in helpers to reduce
  coupling between orchestration and IO concerns.
