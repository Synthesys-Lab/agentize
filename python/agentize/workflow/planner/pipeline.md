# pipeline.py

Planner pipeline implementation built on the Session DSL. Provides the canonical example of the imperative workflow API.

## External Interfaces

### `run_planner_pipeline()`

```python
def run_planner_pipeline(
    feature_desc: str,
    *,
    output_dir: str | Path = ".tmp",
    backends: dict[str, tuple[str, str]] | None = None,
    runner: Callable[..., subprocess.CompletedProcess] = run_acw,
    prefix: str | None = None,
    output_suffix: str = "-output.md",
    skip_consensus: bool = False,
) -> dict[str, StageResult]
```

Runs the 5-stage planner pipeline (understander → bold → critique → reducer → consensus).
Returns a mapping of stage names to `StageResult` objects. When `skip_consensus` is set,
only the first four stages are executed.

### `run_consensus_stage()`

```python
def run_consensus_stage(
    feature_desc: str,
    *,
    bold_path: Path,
    critique_path: Path,
    reducer_path: Path,
    output_dir: Path,
    prefix: str,
    stage_backends: dict[str, tuple[str, str]],
    runner: Callable[..., subprocess.CompletedProcess] = run_acw,
) -> StageResult
```

Runs the consensus stage independently, writing the consensus prompt and output
artifacts (`*-consensus-input.md`, `*-consensus.md`).

### `StageResult`

`StageResult` is re-exported from the Session DSL and represents a single stage result.

## Internal Helpers

### Prompt rendering

- `_render_stage_prompt()`: Builds prompts by concatenating agent templates, plan-guideline
  content, the feature description, and prior outputs.
- `_render_consensus_prompt()`: Renders the external-consensus template with the
  combined reports from bold/critique/reducer.

### Stage configuration

- `DEFAULT_BACKENDS`, `STAGE_TOOLS`, `STAGE_PERMISSION_MODE`: Default per-stage settings.
- `AGENT_PROMPTS` and `STAGES_WITH_PLAN_GUIDELINE`: Prompt composition inputs.

## Design Rationale

- **Session DSL as baseline**: The planner pipeline demonstrates the imperative Session API
  with a parallel-only critique/reducer stage.
- **Explicit artifacts**: Stage-specific input/output files remain predictable and
  match CLI documentation.
- **Reusable consensus stage**: Running consensus separately preserves the `.txt`
  artifacts for debate stages while keeping the final plan in markdown.
