---
name: agent-review
description: Review code changes via agent with isolated context and Opus model
---

# Agent Review Command

Execute code review using the code-quality-reviewer agent in isolated context with Opus model for enhanced long context analysis.

Invoke the command: /agent-review

## Inputs

**From current branch:**
- All changes between main and HEAD (handled by agent)

## Outputs

**Terminal output:**
- Comprehensive code review report from code-quality-reviewer agent
- Same format as /code-review with 3-phase analysis

## Agent Integration

### Step 1: Invoke Code-Quality-Reviewer Agent

Use Task tool to invoke the code-quality-reviewer agent:

**Task Tool Parameters:**
- `subagent_type: 'code-quality-reviewer'`
- `prompt: "Review changes on current branch"`
- `description: "Comprehensive code review"`

The agent will:
- Validate current branch (not main)
- Get changed files and full diff
- Execute review-standard skill (all 3 phases)
- Generate structured review report

### Step 2: Display Agent Report

Present the agent's review report to the user.

The report includes:
- Phase 1: Documentation Quality Review
- Phase 2: Code Quality & Reuse Review
- Phase 3: Advanced Code Quality Review
- Overall Assessment with actionable recommendations

## Comparison with /code-review

| Feature | /agent-review | /code-review |
|---------|---------------|--------------|
| **Execution** | Isolated agent context | Main conversation |
| **Model** | Opus (long context) | Current model |
| **Best for** | Large diffs (>500 lines) | Small diffs |
| **Context** | Clean, focused | Full conversation |

Both use the same review-standard skill and produce equivalent quality reviews.
