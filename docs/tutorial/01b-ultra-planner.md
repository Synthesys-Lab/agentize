# Tutorial 01b: Ultra Planner (Multi-Agent Debate Planning)

**Read time: 5 minutes**

Learn how to use multi-agent debate-based planning for complex features with `/ultra-planner`.

## What is `/ultra-planner`?

`/ultra-planner` automatically routes to the optimal planning workflow based on estimated complexity:

### Automatic Routing

After the **Understander** agent gathers codebase context, it estimates modification complexity and recommends a path:

- **Lite path** (<200 LOC): Single-agent planner for fast, simple modifications (1-2 min)
- **Full path** (≥200 LOC): Multi-agent debate for complex features (6-12 min)

### Full Debate (for complex features)

The full path uses **three AI agents** in a serial debate workflow:

1. **Bold Proposer**: Researches SOTA solutions and proposes innovative approaches
2. **Proposal Critique**: Validates assumptions and identifies technical risks
3. **Proposal Reducer**: Simplifies following "less is more" philosophy

Bold-proposer runs first to generate a concrete proposal, then Critique and Reducer both analyze that proposal (running in parallel with each other). An external reviewer (Codex/Claude Opus) synthesizes all three perspectives into a consensus plan.

## When to Use It?

**Use `/ultra-planner`** for all feature planning. It automatically routes:

- **Simple features** (<200 LOC) → Lite path (1-2 min, ~$0.50-1.50)
- **Complex features** (≥200 LOC) → Full debate (6-12 min, ~$2.50-6)

**Use `/ultra-planner --force-full`** when:
- You want thorough multi-perspective analysis even for simple changes
- The understander's estimate seems too low

**Use `/plan-an-issue`** as a standalone alternative:
- When you want direct single-agent planning without understander
- For time-sensitive planning with known scope

## Workflow Example

**1. Invoke the command:**
```
User: /ultra-planner Add user authentication with JWT tokens and role-based access control
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

To refine: /ultra-planner --refine 42
To implement: /issue-to-impl 42
```

## Refinement with `--refine` Mode

Improve an existing plan issue by running the debate again:

```
/ultra-planner --refine 42
```

The agents analyze the current plan and propose improvements. Useful when the initial consensus feels over-complicated or you want to explore simpler alternatives.

**Optional refinement focus:**
```
/ultra-planner --refine 42 Focus on reducing complexity
```

### Label-Based Auto Refinement

When running with `lol serve`, you can trigger refinement without invoking the command manually:

1. Ensure the issue is in `Proposed` status (not `Plan Accepted`)
2. Add the `agentize:refine` label via GitHub UI or CLI:
   ```bash
   gh issue edit 42 --add-label agentize:refine
   ```
3. The server will pick up the issue on the next poll and run refinement automatically
4. After refinement completes, the label is removed and status stays `Proposed`

This enables stakeholders to request plan improvements without CLI access.

## Tips

1. **Provide context**: "Add JWT auth for API access" (not just "Add auth")
2. **Right-size features**: Don't use for trivial changes, do use for complex ones
3. **Review all perspectives**: Bold shows innovation, Critique shows risks, Reducer shows simplicity
4. **Refine when needed**: First consensus not perfect? Use `--refine`
5. **Start simple**: Try `/plan-an-issue` first, escalate to `/ultra-planner` if needed

## Cost & Time

**With automatic routing:**

| Path | Complexity | Time | Cost |
|------|------------|------|------|
| Lite | <200 LOC | 1-2 min | ~$0.50-1.50 |
| Full | ≥200 LOC | 6-12 min | ~$2.50-6 |

**Value of full path**: Multiple perspectives, thorough validation, balanced plans

## Next Steps

After `/ultra-planner` creates your GitHub issue:

1. Review the issue on GitHub
2. Use `/issue-to-impl <issue-number>` to start implementation (Tutorial 02)
3. Validate and adjust the plan as you implement

**When in doubt**: Start with `/plan-an-issue`, escalate to `/ultra-planner` if you need deeper analysis.
