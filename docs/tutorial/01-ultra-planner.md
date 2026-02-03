# Tutorial 01: CLI Planning with `lol plan`

**Primary planning tutorial**: Use this as the default entry point for planning features.

**Read time: 5 minutes**

Learn how to use multi-agent debate-based planning with `lol plan --editor` (CLI-first). If you prefer the Claude UI, `/ultra-planner` provides auto-routing and `--force-full` (see `docs/feat/core/ultra-planner.md`).

## What is `lol plan`?

`lol plan` runs the multi-agent debate pipeline to produce a consensus implementation plan. It is the preferred CLI entrypoint for planning and is documented in `docs/cli/lol.md` and `docs/cli/planner.md`.

### Basic usage

Compose the feature description in your editor:

```
lol plan --editor
```

`--editor` opens `$EDITOR`. If `$EDITOR` is not set, pass the description directly:

```
lol plan "Add user authentication with JWT tokens and role-based access control"
```

### Refinement with `--refine`

Improve an existing plan issue by running the debate again:

```
lol plan --refine 42
```

Optional refinement focus:

```
lol plan --refine 42 "Focus on reducing complexity"
```

## Claude UI Equivalent: `/ultra-planner`

`/ultra-planner` is the Claude UI interface for planning. It uses auto-routing and supports `--force-full`. See `docs/feat/core/ultra-planner.md` for full behavior details.

### Automatic Routing

After the **Understander** agent gathers codebase context, it checks lite conditions:

- **Lite path** (when ALL met): Single-agent planner (1-2 min)
  - All knowledge within repo (no internet research needed)
  - < 5 files affected
  - < 150 LOC total
- **Full path** (otherwise): Multi-agent debate with web research (6-12 min)

### Full Debate (for complex features)

The full path uses **three AI agents** in a serial debate workflow:

1. **Bold Proposer**: Researches SOTA solutions and proposes innovative approaches
2. **Proposal Critique**: Validates assumptions and identifies technical risks
3. **Proposal Reducer**: Simplifies following "less is more" philosophy

Bold-proposer runs first to generate a concrete proposal, then Critique and Reducer both analyze that proposal (running in parallel with each other). An external reviewer (Codex/Claude Opus) synthesizes all three perspectives into a consensus plan.

## When to Use It?

**Use `lol plan`** for all feature planning in the CLI. It always runs the multi-agent pipeline documented in `docs/cli/lol.md`.

**Use `/ultra-planner`** when you want Claude UI convenience or auto-routing.

**Use `/ultra-planner --force-full`** when:
- You want thorough multi-perspective analysis even for simple changes
- The feature needs SOTA research even if LOC is low

**Use `/plan-to-issue`** as a standalone alternative:
- When you have an existing plan and want to convert it to a GitHub issue
- For time-sensitive planning with known scope

## Workflow Example

**1. Invoke the command:**
```
lol plan "Add user authentication with JWT tokens and role-based access control"
```

**2. Bold-proposer generates proposal (1-2 minutes):**
```
BOLD PROPOSER: OAuth2 + JWT + RBAC (~450 LOC)
```

**3. Critique and Reducer analyze Bold's proposal (2-3 minutes):**
```
CRITIQUE: Medium feasibility, 2 critical risks (token storage, complexity)
REDUCER: Simple JWT only (~180 LOC, 60% reduction)
```

**4. External consensus synthesizes:**
```
Consensus: JWT + basic roles (~280 LOC)
- From Bold: JWT tokens + role-based access
- From Critique: httpOnly cookies for security
- From Reducer: Removed OAuth2 complexity

Documentation Planning:
- docs/api/authentication.md — create JWT auth API docs
- src/auth/README.md — create module overview
- src/middleware/auth.js — add interface documentation
```

**5. Plan issue auto-updated:**
```
Plan issue #42 updated with consensus plan.
URL: https://github.com/user/repo/issues/42

To refine (CLI): lol plan --refine 42
To refine (Claude UI): /ultra-planner --refine 42
To implement (CLI): lol impl 42
```

## Label-Based Auto Refinement

When running with `lol serve`, you can trigger refinement without invoking the command manually:

1. Ensure the issue is in `Proposed` status (not `Plan Accepted`)
2. Add the `agentize:refine` label via GitHub UI or CLI:
   ```bash
   gh issue edit 42 --add-label agentize:refine
   ```
3. The server will pick up the issue on the next poll and run `/ultra-planner --refine` (current server behavior per `docs/cli/lol.md`)
4. After refinement completes, the label is removed and status stays `Proposed`

This enables stakeholders to request plan improvements without CLI access.

## Tips

1. **Provide context**: "Add JWT auth for API access" (not just "Add auth")
2. **Right-size features**: Don't use for trivial changes, do use for complex ones
3. **Review all perspectives**: Bold shows innovation, Critique shows risks, Reducer shows simplicity
4. **Refine when needed**: First consensus not perfect? Use `lol plan --refine`
5. **Choose your interface**: `lol plan` for CLI, `/ultra-planner` for auto-routing in Claude UI

## Dry-Run Mode

Preview what would be created without making GitHub changes:

```
lol plan --dry-run "Add user authentication with JWT tokens"
```

**What happens:**
- Full debate workflow runs (understander → bold-proposer → critique/reducer → consensus)
- Plan files saved to `.tmp/` for review
- Prints summary of what issue would be created

**What doesn't happen:**
- No placeholder issue created
- No issue body updated
- No labels added

**Cost note:** Token costs are similar to regular runs since agents still execute. Use `--dry-run` when you want to review the plan before committing to GitHub.

## Cost & Time (Claude UI Auto-Routing)

**With automatic routing in `/ultra-planner`:**

| Path | Conditions | Time | Cost |
|------|------------|------|------|
| Lite | repo-only, <5 files, <150 LOC | 1-2 min | ~$0.30-0.80 |
| Full | needs research or complex | 6-12 min | ~$2.50-6 |

**Why lite is cheaper**: No external consensus step (single agent, nothing to synthesize)

**Value of full path**: Multiple perspectives, thorough validation, balanced plans

## Plan → Impl (End-to-End)

After `lol plan` creates your GitHub issue, continue with `lol impl <issue-number>` (see `docs/tutorial/02-issue-to-impl.md`).

### Backend Configuration

Configure planner backends in `.agentize.local.yaml`:

```yaml
planner:
  backend: claude:opus             # Default backend for all stages
  understander: claude:sonnet      # Override understander stage
  bold: claude:opus                # Override bold-proposer stage
  critique: claude:opus            # Override critique stage
  reducer: claude:opus             # Override reducer stage

workflows:
  impl:
    model: opus                    # Default model for lol impl
```

**Note:** `lol impl --backend <provider:model>` overrides `workflows.impl.model` for a single run (see `docs/cli/lol.md`).

## Next Steps

1. Review the plan issue on GitHub
2. Run `lol impl <issue-number>` to start implementation (Tutorial 02)
3. Use `lol plan --refine <issue>` if the plan needs adjustments

**When in doubt**: Use `lol plan` - it keeps planning CLI-first while the Claude UI remains available.
