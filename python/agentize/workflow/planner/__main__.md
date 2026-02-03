# Module: agentize.workflow.planner.__main__

Pipeline orchestration and CLI entry point for the 5-stage planner workflow.

## External Interface

### CLI

```bash
python -m agentize.workflow.planner \
  --feature-desc "Add dark mode toggle" \
  --issue-mode true \
  --verbose false \
  --refine-issue-number ""
```

**Parameters:**
- `--feature-desc`: Feature description or refine focus.
- `--issue-mode`: `true` or `false` to enable GitHub issue publish flow.
- `--verbose`: `true` or `false` to enable stage progress logs.
- `--refine-issue-number`: Issue number to refine (optional).

**Exit codes:**
- `0`: Success.
- `1`: Issue publish failure or missing prerequisites.
- `2`: Invalid argument combination or missing required inputs.

### `StageResult`

```python
@dataclass
class StageResult:
    stage: str
    input_path: Path
    output_path: Path
    process: subprocess.CompletedProcess
```

Holds per-stage execution metadata and the completed process handle.

### `run_planner_pipeline`

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
    progress: Optional[PlannerTTY] = None,
) -> dict[str, StageResult]:
```

Executes the understander → bold → critique → reducer → consensus pipeline and returns
per-stage results. When `runner` is `run_acw`, the pipeline wraps each stage with the
`ACW` runner for provider validation and timing logs.

## Internal Helpers

### Prompt rendering
- `_strip_yaml_frontmatter()`: Remove YAML frontmatter from prompt templates.
- `_read_prompt_file()`: Load prompt templates from disk.
- `_render_stage_prompt()`: Compose stage prompt with feature description and prior output.
- `_render_consensus_prompt()`: Compose final consensus prompt from prior stage outputs.

### Backend resolution
- `_resolve_repo_root()`: Determine repository root for config lookup.
- `_load_planner_backend_config()`: Load backend overrides from YAML config.
- `_validate_backend_spec()`: Validate provider:model strings.
- `_split_backend_spec()`: Parse provider/model from backend spec.
- `_resolve_stage_backends()`: Merge overrides with defaults.

### Issue workflow
- `_gh_available()`: Check for GitHub CLI availability.
- `_issue_create()`: Create issue scaffolding for plan output.
- `_issue_fetch()`: Load issue content for refinement.
- `_issue_publish()`: Update issue with plan output.
- `_extract_plan_title()`: Extract plan title from consensus output.
- `_apply_issue_tag()`: Prefix plan title with issue label.

### Consensus-only runner
- `_run_consensus_stage()`: Execute just the consensus stage for refinement flows.

### Entry point
- `main()`: CLI entry point that wires argument parsing, config resolution, and pipeline execution.
