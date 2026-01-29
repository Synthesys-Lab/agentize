# Planner Pipeline (Internal)

Internal pipeline module used by `lol plan` to run the multi-agent debate workflow. The standalone `planner` command has been removed.

## Usage

```bash
lol plan [--dry-run] [--verbose] [--refine <issue-no> [refinement-instructions]] \
  [--backend <provider:model>] [--understander <provider:model>] \
  [--bold <provider:model>] [--critique <provider:model>] \
  [--reducer <provider:model>] \
  "<feature-description>"
lol plan --refine <issue-no> [refinement-instructions]
```

## Pipeline Stages

`lol plan` runs the full multi-agent debate pipeline for a feature description:

1. **Understander** (sonnet) - Gathers codebase context with `Read,Grep,Glob` tools
2. **Bold-proposer** (opus) - Researches SOTA solutions and proposes innovative approaches with `Read,Grep,Glob,WebSearch,WebFetch` tools and `--permission-mode plan`
3. **Critique** (opus) - Validates assumptions and analyzes feasibility (runs in parallel with Reducer)
4. **Reducer** (opus) - Simplifies proposal following "less is more" philosophy (runs in parallel with Critique)
5. **External consensus** - Synthesizes final plan from the three reports

Both critique and reducer append plan-guideline content and run in parallel via background processes.

### `--dry-run` (optional flag)

Skips GitHub issue creation and uses timestamp-based artifact naming. The pipeline still runs fully; only the issue creation/publish step is skipped.

### `--refine <issue-no> [refinement-instructions]`

Refines an existing plan issue by fetching its body from GitHub and rerunning the debate. Optional refinement instructions are appended to the context to steer the agents. Refinement runs still write artifacts with `issue-refine-<N>` prefixes and update the existing issue unless `--dry-run` is set. Requires authenticated `gh` access to read the issue body.

### `--verbose` (optional flag)

Prints detailed stage logs. By default, the pipeline runs in quiet mode, printing only stage names and output paths.

### Backend Selection (optional flags)

You can override the backend per stage using `provider:model` strings:

- `--backend <provider:model>`: Default backend for all stages
- `--understander <provider:model>`: Override understander stage
- `--bold <provider:model>`: Override bold-proposer stage
- `--critique <provider:model>`: Override critique stage
- `--reducer <provider:model>`: Override reducer stage

Stage-specific flags override `--backend`. Defaults remain `claude:sonnet` (understander) and `claude:opus` (others).

Example:

```bash
lol plan --understander cursor:gpt-5.2-codex "Plan with cursor understander"
```

### Default Issue Creation

By default, `lol plan` creates a placeholder GitHub issue before the pipeline runs using a truncated placeholder title (`[plan] placeholder: <first 50 chars>...`), and uses `issue-{N}` artifact naming. After the consensus stage completes, the issue body is updated with the final plan, the title is set from the first `Implementation Plan:` or `Consensus Plan:` header in the consensus file (fallback: truncated feature description), and the `agentize:plan` label is applied.

When `--refine` is used, no placeholder issue is created. The issue body is fetched and reused as debate context, and the issue is updated in-place after the consensus stage (unless `--dry-run` is set).

Requires `gh` CLI to be installed and authenticated. If `gh` is unavailable or issue creation fails, logs a warning and falls back to timestamp-based artifact naming.

## Prompt Rendering

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
.tmp/issue-refine-{N}-understander.txt  # Refinement artifacts (issue body context)
.tmp/issue-refine-{N}-bold.txt
.tmp/issue-refine-{N}-critique.txt
.tmp/issue-refine-{N}-reducer.txt
.tmp/issue-refine-{N}-consensus.md      # Refinement consensus (published unless --dry-run)
```

## Relationship to /ultra-planner

The `/ultra-planner` command remains the Claude Code interface for multi-agent planning with automatic issue creation and refinement. `lol plan` provides the same debate pipeline as a shell function for:
- Scripted or automated workflows
- CI/CD integration
- Direct invocation without Claude Code

See `docs/feat/core/ultra-planner.md` and `docs/tutorial/01-ultra-planner.md` for the full `/ultra-planner` command documentation.

## Visual Output

When stderr is a TTY, `lol plan` emits visual feedback during pipeline execution:

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
