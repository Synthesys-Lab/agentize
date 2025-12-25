# External Consensus Skill

## Purpose

Synthesize a balanced, consensus implementation plan from multi-agent debate reports using external AI review (Codex or Claude Opus).

This skill acts as the "tie-breaker" and "integrator" in the ultra-planner workflow, resolving conflicts between three agent perspectives and combining their insights into a coherent implementation plan.

## Files

- **SKILL.md** - Main skill implementation with detailed workflow
- **external-review-prompt.md** - AI prompt template for external consensus review

## Integration

### Used By
- `ultra-planner` command - Invoked after debate-based-planning skill completes

### Outputs To
- `open-issue` skill - Consensus plan becomes GitHub issue body
- User approval - Plan presented for review before issue creation

## Dependencies

### Required
- **scripts/external-review.sh** - Shell script that invokes external CLI tools
- **Combined debate report** - Output from debate-based-planning skill (3 agents)

### External Tools (one required)
- **Codex CLI** (preferred) - For OpenAI GPT-4 based consensus
- **Claude CLI** (fallback) - For Anthropic Opus based consensus

### Templates
- **external-review-prompt.md** - Prompt template with placeholders:
  - `{{FEATURE_NAME}}` - Short feature name
  - `{{FEATURE_DESCRIPTION}}` - Brief description
  - `{{COMBINED_REPORT}}` - Full 3-agent debate report

## How It Works

1. Loads combined debate report from `.tmp/debate-report-*.md`
2. Fills prompt template with feature context and debate content
3. Invokes external AI (Codex or Claude Opus) to synthesize consensus
4. Validates output has required implementation plan sections
5. Saves consensus plan to `.tmp/consensus-plan-*.md`
6. Returns summary with LOC estimate and key decisions

## Notes

- External reviewer provides **neutral, unbiased** perspective
- Codex preferred for **cost and speed** (~$0.10-0.50)
- Claude Opus fallback with **same capability** (~$0.50-2.00)
- Execution time: **1-3 minutes** depending on model and API latency
- Manual review available if both tools unavailable
