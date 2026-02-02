# Planner Pipeline

Python implementation of the 5-stage planner workflow.

## Design Rationale

The Python planner pipeline mirrors the shell-based `src/cli/planner/pipeline.sh` implementation while providing Python-native interfaces for scripting and testing. Key design decisions:

1. **Prompt Reuse**: Directly reads prompts from `.claude-plugin/agents/*.md` and `.claude-plugin/skills/plan-guideline/SKILL.md` rather than duplicating content. This prevents behavioral drift between shell and Python implementations.

2. **Dependency Injection**: The `runner` parameter allows injecting a stub executor for testing, eliminating the need for actual LLM calls in unit tests.

3. **Parallel Execution**: Critique and reducer stages are independent and run in parallel by default using `ThreadPoolExecutor`. The `parallel=False` option enforces deterministic ordering for debugging.

4. **Artifact Persistence**: All input prompts and outputs are written to `output_dir` with a stable prefix, enabling post-hoc analysis and reproducibility.

## Pipeline Flow

```
┌─────────────┐
│ understander│ ← Base prompt only (no plan-guideline)
└──────┬──────┘
       ↓
┌─────────────┐
│    bold     │ ← Base prompt + plan-guideline + understander output
└──────┬──────┘
       ↓
┌──────┴──────┐
│  parallel   │
├─────────────┤
│  critique   │ ← Base prompt + plan-guideline + bold output
│  reducer    │ ← Base prompt + plan-guideline + bold output
└──────┬──────┘
       ↓
┌─────────────┐
│  consensus  │ ← External review template + all prior outputs
└─────────────┘
```

## Prompt Rendering

Each stage prompt is constructed by:

1. **Strip YAML Frontmatter**: Remove any `---` delimited frontmatter from base prompts
2. **Append Plan Guideline**: For bold/critique/reducer stages, append the plan-guideline content
3. **Append Feature Description**: Add `# Feature Request\n\n{feature_desc}`
4. **Append Previous Output**: Add `# Previous Stage Output\n\n{output}` when chaining

### Consensus Prompt

The consensus stage uses a different template (`external-review-prompt.md`) with placeholders:
- `{{FEATURE_DESCRIPTION}}`: The original feature request
- `{{COMBINED_REPORT}}`: Concatenated bold + critique + reducer outputs

## Artifact Layout

```
{output_dir}/
├── {prefix}-understander-input.md
├── {prefix}-understander-output.md
├── {prefix}-bold-input.md
├── {prefix}-bold-output.md
├── {prefix}-critique-input.md
├── {prefix}-critique-output.md
├── {prefix}-reducer-input.md
├── {prefix}-reducer-output.md
├── {prefix}-consensus-input.md
└── {prefix}-consensus-output.md
```

The prefix defaults to a timestamp (`YYYYMMDD-HHMMSS`) but can be overridden for reproducible artifact names.

## Backend Configuration

The `backends` parameter maps stage names to `(provider, model)` tuples:

```python
backends = {
    "understander": ("claude", "haiku"),  # Fast, simple stage
    "bold": ("claude", "sonnet"),
    "critique": ("claude", "sonnet"),
    "reducer": ("claude", "sonnet"),
    "consensus": ("claude", "opus"),      # Highest quality for synthesis
}
```

When a stage is not specified, it defaults to `("claude", "sonnet")`.

## Error Handling

- **Missing Prompts**: Raises `FileNotFoundError` with the exact missing path
- **Stage Failure**: Raises `RuntimeError` with stage name and non-zero exit code
- **Timeout**: Propagates `subprocess.TimeoutExpired` from the runner

Partial results are preserved in `output_dir` for debugging even when a stage fails.
