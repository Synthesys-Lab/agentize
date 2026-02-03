# Planner Pipeline Module

Pipeline orchestration and CLI backend for `python -m agentize.workflow.planner`.

## External Interface

### `run_planner_pipeline(...) -> dict[str, StageResult]`

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

Execute the 5-stage planner pipeline (understander → bold → critique → reducer → consensus).

**Parameters:**
- `feature_desc`: Feature request description
- `output_dir`: Directory to write artifacts
- `backends`: Stage backend overrides (`{stage: (provider, model)}`)
- `parallel`: Run critique/reducer in parallel
- `runner`: Callable for executing a stage (defaults to `run_acw`)
- `prefix`: Artifact filename prefix (timestamp-based when omitted)
- `output_suffix`: Suffix appended to output files
- `skip_consensus`: Skip consensus stage when external synthesis is used
- `progress`: Optional `PlannerTTY` for animation/timing logs

**Returns:** Mapping of stage name to `StageResult`

**Raises:**
- `FileNotFoundError` if prompt templates are missing
- `RuntimeError` if any stage fails

### `StageResult`

```python
@dataclass
class StageResult:
    stage: str
    input_path: Path
    output_path: Path
    process: subprocess.CompletedProcess
```

Container for a single pipeline stage execution.

### `main(argv: list[str]) -> int`

CLI entrypoint that coordinates issue creation, pipeline execution, and consensus publishing.

**Arguments:**
- `--feature-desc`: Feature description or refinement focus
- `--issue-mode`: `true` or `false` (create/update GitHub issue)
- `--verbose`: `true` or `false` for verbose logs
- `--refine-issue-number`: Issue number to refine (optional)

**Exit codes:**
- `0`: Success
- `1`: Setup/config errors (repo root, config validation)
- `2`: Pipeline execution errors

### CLI Invocation

```bash
python -m agentize.workflow.planner --feature-desc "Add dark mode toggle" --issue-mode true
```

## Internal Helpers

### Prompt rendering
- `_strip_yaml_frontmatter(content: str) -> str`
- `_read_prompt_file(path: Path) -> str`
- `_render_stage_prompt(stage, feature_desc, agentize_home, previous_output)`
- `_render_consensus_prompt(feature_desc, bold_output, critique_output, reducer_output, agentize_home)`

### Backend configuration
- `_load_planner_backend_config(repo_root: Path, start_dir: Path) -> dict[str, str]`
- `_validate_backend_spec(spec: str, label: str) -> None`
- `_resolve_stage_backends(backend_config: dict[str, str]) -> dict[str, tuple[str, str]]`

### Issue helpers
- `_gh_available() -> bool`
- `_issue_create(feature_desc: str) -> tuple[Optional[str], Optional[str]]`
- `_issue_fetch(issue_number: str) -> tuple[str, Optional[str]]`
- `_issue_publish(issue_number: str, title: str, body_file: Path) -> bool`
- `_extract_plan_title(consensus_path: Path) -> str`
- `_apply_issue_tag(plan_title: str, issue_number: str) -> str`

### Consensus stage
- `_run_consensus_stage(...) -> StageResult`

### Repo and formatting utilities
- `_resolve_repo_root() -> Path`
- `_shorten_feature_desc(desc: str, max_len: int = 50) -> str`
- `_collapse_whitespace(text: str) -> str`
