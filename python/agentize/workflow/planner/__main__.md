# __main__.py

Planner pipeline orchestration and CLI backend for `python -m agentize.workflow.planner`.

## External Interface

### StageResult

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

### run_planner_pipeline()

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
    progress: PlannerTTY | None = None,
) -> dict[str, StageResult]
```

Executes the 5-stage planner pipeline. When `runner` is `run_acw`, stages run through the
`ACW` class (provider validation + start/finish timing logs). When a custom runner is
provided (tests), it is invoked directly.

### main()

```python
def main(argv: list[str]) -> int
```

CLI entrypoint for the planner backend. Parses args, resolves repo root and backend
configuration, runs stages, publishes plan updates (when enabled), and prints progress
output. Returns process exit code.

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

- `_issue_create()`, `_issue_fetch()`, `_update_issue_body()`, `_update_issue_title()`:
  GitHub issue lifecycle for plan publishing.
- `_extract_plan_title()`, `_apply_issue_tag()`: Plan title parsing and issue tagging.

### Backend selection

- `_load_planner_backend_config()`, `_resolve_stage_backends()`: Reads
  `.agentize.local.yaml` and resolves provider/model pairs per stage.

## Design Rationale

- **Unified runner path**: The pipeline always uses `ACW` class for stage execution.
  Custom runners (for testing) are injected via the `ACW.runner` parameter, avoiding
  identity checks like `runner is run_acw`. This keeps ACW timing logs available
  regardless of the underlying runner function.
- **Isolation**: Prompt rendering and issue/publish logic are kept in helpers to reduce
  coupling between orchestration and IO concerns.
