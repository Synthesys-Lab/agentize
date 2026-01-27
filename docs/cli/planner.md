# planner CLI

Standalone shell function that runs the multi-agent debate pipeline with file-based I/O, independent of Claude Code's `/ultra-planner` command.

## Usage

```bash
planner plan "<feature-description>"
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
.tmp/{timestamp}-understander.txt       # Codebase context
.tmp/{timestamp}-bold.txt               # Bold proposal
.tmp/{timestamp}-critique.txt           # Critique report
.tmp/{timestamp}-reducer.txt            # Simplified proposal
.tmp/{timestamp}-consensus.md           # Final consensus plan
```

## Relationship to /ultra-planner

The `/ultra-planner` command remains the Claude Code interface for multi-agent planning with automatic issue creation and refinement. `planner plan` provides the same debate pipeline as a shell function for:
- Scripted or automated workflows
- CI/CD integration
- Direct invocation without Claude Code

See `docs/feat/core/ultra-planner.md` and `docs/tutorial/01-ultra-planner.md` for the full `/ultra-planner` command documentation.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Pipeline completed successfully |
| 1 | Missing or invalid arguments |
| 2 | Stage execution failure |
