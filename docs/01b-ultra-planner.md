# Tutorial 01b: Ultra Planner (Multi-Agent Debate Planning)

**Read time: 5 minutes**

Learn how to use multi-agent debate-based planning for complex features with `/ultra-planner`.

## What is `/ultra-planner`?

`/ultra-planner` uses **three AI agents** in a serial debate workflow to create balanced implementation plans:

1. **Bold Proposer**: Runs first, researches SOTA solutions and proposes innovative approaches
2. **Proposal Critique**: Analyzes Bold's proposal, validates assumptions and identifies technical risks
3. **Proposal Reducer**: Analyzes Bold's proposal, simplifies following "less is more" philosophy

Bold-proposer runs first to generate a concrete proposal, then Critique and Reducer both analyze that proposal (running in parallel with each other). An external reviewer (Codex/Claude Opus) synthesizes all three perspectives into a consensus plan.

## When to Use It?

**Use `/ultra-planner`** for:
- Large features (≥400 LOC)
- Complex architectural decisions
- High-risk features needing validation
- Innovative solutions requiring research

**Use `/plan-an-issue`** for:
- Small to medium features (<400 LOC)
- Clear, straightforward implementations
- Time-sensitive planning (1-2 min vs 5-10 min)

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
```

**5. You approve:**
```
Options:
1. Approve and create GitHub issue
2. Refine plan (/ultra-planner --refine <file>)
3. Abandon

Your choice: 1

GitHub issue created: #42
```

## Refinement Mode

Improve an existing plan by running the debate again:

```
/ultra-planner --refine .tmp/consensus-plan-20251225-160245.md
```

The agents analyze the current plan and propose improvements. Useful when the initial consensus feels over-complicated or you want to explore simpler alternatives.

## Tips

1. **Provide context**: "Add JWT auth for API access" (not just "Add auth")
2. **Right-size features**: Don't use for trivial changes, do use for complex ones
3. **Review all perspectives**: Bold shows innovation, Critique shows risks, Reducer shows simplicity
4. **Refine when needed**: First consensus not perfect? Use `--refine`
5. **Start simple**: Try `/plan-an-issue` first, escalate to `/ultra-planner` if needed

## Cost & Time

- **Time**: 5-10 minutes (vs 1-2 min for single-agent)
- **Cost**: ~$2-5 (vs ~$0.50-1 for single-agent)
- **Value**: Multiple perspectives, thorough validation, balanced plans

## Next Steps

After `/ultra-planner` creates your GitHub issue:

1. Review the issue on GitHub
2. Use `/issue-to-impl <issue-number>` to start implementation (Tutorial 02)
3. Validate and adjust the plan as you implement

**When in doubt**: Start with `/plan-an-issue`, escalate to `/ultra-planner` if you need deeper analysis.
