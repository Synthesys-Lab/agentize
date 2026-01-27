# planner CLI

Standalone shell function that runs the multi-agent debate pipeline with file-based I/O, independent of Claude Code's `/ultra-planner` command. The preferred entrypoint is `lol plan`; the `planner` command is retained as a legacy alias.

## Usage

```bash
lol plan [--dry-run] [--verbose] "<feature-description>"
planner plan [--dry-run] [--verbose] "<feature-description>"  # legacy alias
planner --help
```

## Subcommands

### `plan`

Runs the full multi-agent debate pipeline for a feature description:

1. **Understander** (sonnet) - Gathers codebase context with `Read,Grep,Glob` tools
2. **Bold-proposer** (opus) - Researches SOTA solutions and proposes innovative approaches with `Read,Grep,Glob,WebSearch,WebFetch` tools and `--permission-mode plan`
3. **Critique** (opus) - Validates assumptions and analyzes feasibility (runs in parallel with Reducer)
4. **Reducer** (opus) - Simplifies proposal following "less is more" philosophy (runs in parallel with Critique)
5. **External consensus** - Synthesizes final plan from the three reports

Both critique and reducer append plan-guideline content and run in parallel via background processes.

### `--dry-run` (optional flag)

Skips GitHub issue creation and uses timestamp-based artifact naming. The pipeline still runs fully; only the issue creation/publish step is skipped.

### `--verbose` (optional flag)

Prints detailed stage logs. By default, the pipeline runs in quiet mode, printing only stage names and output paths.

### Default Issue Creation

By default, `plan` creates a placeholder GitHub issue before the pipeline runs and uses `issue-{N}` artifact naming. After the consensus stage completes, the issue body is updated with the final plan and the `agentize:plan` label is applied.

Requires `gh` CLI to be installed and authenticated. If `gh` is unavailable or issue creation fails, logs a warning and falls back to timestamp-based artifact naming.

### `--help`

Displays usage information and available subcommands.

## Pipeline Stages

Each stage uses `acw` for file-based CLI invocation. Prompts are rendered at runtime by concatenating:
- Agent base prompt (from `.claude-plugin/agents/*.md`)
- Plan-guideline content (from `.claude-plugin/skills/plan-guideline/SKILL.md`, YAML frontmatter stripped)
- Feature description and previous stage output

## Artifacts

All intermediate and final artifacts are written to `.tmp/`:

```
.tmp/{timestamp}-understander.txt       # Default (no --issue)
.tmp/{timestamp}-bold.txt
.tmp/{timestamp}-critique.txt
.tmp/{timestamp}-reducer.txt
.tmp/{timestamp}-consensus.md           # Final consensus plan

.tmp/issue-{N}-understander.txt         # When --issue succeeds
.tmp/issue-{N}-bold.txt
.tmp/issue-{N}-critique.txt
.tmp/issue-{N}-reducer.txt
.tmp/issue-{N}-consensus.md             # Final consensus plan (also published to issue)
```

## Relationship to /ultra-planner

The `/ultra-planner` command remains the Claude Code interface for multi-agent planning with automatic issue creation and refinement. `planner plan` provides the same debate pipeline as a shell function for:
- Scripted or automated workflows
- CI/CD integration
- Direct invocation without Claude Code

See `docs/feat/core/ultra-planner.md` and `docs/tutorial/01-ultra-planner.md` for the full `/ultra-planner` command documentation.

## Visual Output

When stderr is a TTY, `planner plan` emits visual feedback during pipeline execution:

- **Colored "Feature:" label** — highlights the feature description at pipeline start.
- **Animated stage dots** — expanding/contracting dot pattern (`.. ... .... ..... .... ...`) while each stage runs.
- **Per-agent timing** — logs elapsed seconds after each stage completes (e.g., `understander agent runs 12s`).
- **Styled issue line** — when `--issue` succeeds, prints `issue created: <url>` at pipeline end.

### Environment Toggles

| Variable | Effect |
|----------|--------|
| `NO_COLOR=1` | Disables all color output (respects [no-color.org](https://no-color.org) convention) |
| `PLANNER_NO_COLOR=1` | Disables planner-specific color output |
| `PLANNER_NO_ANIM=1` | Disables dot animation (useful for CI or piped output) |

Animation and color are automatically disabled when stderr is not a TTY.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Pipeline completed successfully |
| 1 | Missing or invalid arguments |
| 2 | Stage execution failure |
