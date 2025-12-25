---
name: debate-based-planning
description: Orchestrate multi-agent debate to generate balanced implementation plans
---

# Debate-Based Planning Skill

This skill orchestrates three specialized agents (bold-proposer, proposal-critique, proposal-reducer) to collaboratively generate implementation plans through structured debate.

## Skill Philosophy

Effective planning benefits from multiple perspectives:
- **Innovation**: Bold proposals push boundaries and explore SOTA solutions
- **Validation**: Critical analysis identifies risks and validates assumptions
- **Simplification**: Reductionist perspective eliminates unnecessary complexity

By combining these perspectives, we generate balanced plans that are innovative yet practical, comprehensive yet simple.

## Skill Overview

When invoked, this skill:

1. **Launches three agents in parallel**: bold-proposer, proposal-critique, proposal-reducer
2. **Collects their reports**: Each agent analyzes the same feature request independently
3. **Combines reports**: Merges all three perspectives into a single document
4. **Returns combined report**: Ready for external consensus review

## Inputs

This skill expects:
- **Feature request**: User's requirements or problem statement
- **Context files** (optional): Relevant codebase files for agents to review
- **Output path**: Where to save the combined report

## Outputs

- **Combined report file**: `.tmp/debate-report-{timestamp}.md` containing all three perspectives
- **Summary**: Brief summary of each agent's key points

## Implementation Workflow

### Step 1: Validate Inputs

Check that required inputs are provided:

```bash
# Feature request must be non-empty
if [ -z "$FEATURE_REQUEST" ]; then
    echo "Error: Feature request is required"
    exit 1
fi
```

**Required inputs:**
- Feature request description

**Optional inputs:**
- Context files to provide to agents
- Custom output path

### Step 2: Prepare Agent Invocations

Create three parallel agent invocations with the same feature request:

**Agent 1: Bold Proposer**
- **Prompt**: "Research and propose an innovative solution for: {feature_request}"
- **Agent**: `bold-proposer`
- **Output**: `.tmp/bold-proposal-{timestamp}.md`

**Agent 2: Proposal Critique**
- **Prompt**: "Analyze the feasibility and risks for: {feature_request}"
- **Agent**: `proposal-critique`
- **Output**: `.tmp/critique-{timestamp}.md`

**Agent 3: Proposal Reducer**
- **Prompt**: "Propose a simplified solution following 'less is more' for: {feature_request}"
- **Agent**: `proposal-reducer`
- **Output**: `.tmp/reducer-{timestamp}.md`

### Step 3: Launch Agents in Parallel

Use the Task tool to launch all three agents simultaneously:

```markdown
Launch three agents in parallel:
1. Task tool with subagent_type='bold-proposer' and prompt from Agent 1
2. Task tool with subagent_type='proposal-critique' and prompt from Agent 2
3. Task tool with subagent_type='proposal-reducer' and prompt from Agent 3
```

**Important**: All three agents must run in **parallel**, not sequentially. Use a single message with three Task tool calls.

### Step 4: Wait for Agent Completion

All three agents run in isolated contexts and will return their results when complete.

**Expected outputs:**
- Bold proposer returns: Innovative proposal with SOTA research
- Critique returns: Risk analysis and feasibility assessment
- Reducer returns: Simplified proposal with complexity analysis

**Error handling:**
- If any agent fails, collect error details
- Report which agent(s) failed and why
- Ask user whether to:
  - Retry failed agent(s)
  - Continue with partial results
  - Abort the debate

### Step 5: Combine Reports

Load the combined report template:

```bash
TEMPLATE=".tmp/templates/debate-combined.md"
```

Substitute variables in template:
- `{{FEATURE_NAME}}`: Extract from feature request (first line or summary)
- `{{TIMESTAMP}}`: Current datetime
- `{{BOLD_PROPOSER_CONTENT}}`: Content from bold-proposer agent
- `{{CRITIQUE_CONTENT}}`: Content from proposal-critique agent
- `{{REDUCER_CONTENT}}`: Content from proposal-reducer agent

**Template structure:**
```markdown
# Multi-Agent Debate Report

**Feature**: {{FEATURE_NAME}}
**Generated**: {{TIMESTAMP}}

[Introduction...]

---

## Part 1: Bold Proposer Report

{{BOLD_PROPOSER_CONTENT}}

---

## Part 2: Proposal Critique Report

{{CRITIQUE_CONTENT}}

---

## Part 3: Proposal Reducer Report

{{REDUCER_CONTENT}}

---

## Next Steps

[Instructions for external consensus review...]
```

### Step 6: Save Combined Report

Write combined report to output file:

```bash
OUTPUT_FILE=".tmp/debate-report-$(date +%Y%m%d-%H%M%S).md"
echo "$COMBINED_REPORT" > "$OUTPUT_FILE"
```

### Step 7: Generate Summary

Extract key points from each report for quick review:

**Bold Proposer Summary:**
- Core innovation proposed
- Key benefits claimed
- Total LOC estimate

**Critique Summary:**
- Critical risks identified (HIGH priority only)
- Feasibility assessment (High/Medium/Low)
- Major concerns

**Reducer Summary:**
- Complexity removed vs. original
- LOC reduction percentage
- Key simplifications applied

### Step 8: Return Results

Output to user:

```
Debate complete! Three perspectives generated:

1. Bold Proposer:
   - Innovation: {key innovation}
   - LOC estimate: ~{N}

2. Critique:
   - Feasibility: {High/Medium/Low}
   - Critical risks: {count}

3. Reducer:
   - LOC estimate: ~{M} ({reduction}% reduction)
   - Simplifications: {count}

Combined report saved to: {output_file}

Next step: Run external consensus review to synthesize final plan.
Use: external-consensus skill
```

## Error Handling

### Agent Launch Failure

One or more agents fail to launch (e.g., agent not found, invalid configuration).

**Response:**
```
Error: Failed to launch agent(s):
- {agent-name}: {error-message}

Please ensure all debate agents are properly configured:
- claude/agents/bold-proposer.md
- claude/agents/proposal-critique.md
- claude/agents/proposal-reducer.md
```

Stop execution.

### Agent Execution Failure

Agent launches but fails during execution (e.g., timeout, internal error).

**Response:**
```
Warning: Agent execution failed:
- {agent-name}: {error-message}

You have {N}/3 successful agent reports.

Options:
1. Retry failed agent: {agent-name}
2. Continue with partial results ({N} perspectives)
3. Abort debate
```

Wait for user decision.

### Template Not Found

Combined report template file doesn't exist.

**Response:**
```
Error: Combined report template not found.

Expected: .tmp/templates/debate-combined.md

Please ensure the template file exists.
```

Stop execution.

### Empty Agent Output

Agent completes but returns empty or invalid output.

**Response:**
```
Warning: Agent returned empty output:
- {agent-name}

This could indicate:
- Agent encountered an error silently
- Feature request was unclear
- Agent configuration issue

Retry agent or check agent logs for details.
```

Ask user whether to retry or continue.

## Usage Examples

### Example 1: Basic Debate

**Input:**
```
Feature request: "Add user authentication to the application with JWT tokens"
```

**Output:**
```
Debate complete! Three perspectives generated:

1. Bold Proposer:
   - Innovation: OAuth2 + JWT with refresh tokens and role-based access control
   - LOC estimate: ~450

2. Critique:
   - Feasibility: Medium
   - Critical risks: 2 (token storage security, session management complexity)

3. Reducer:
   - LOC estimate: ~180 (60% reduction)
   - Simplifications: Removed OAuth2, simplified to basic JWT auth

Combined report saved to: .tmp/debate-report-20251225-155030.md

Next step: Run external consensus review to synthesize final plan.
```

### Example 2: Debate with Context Files

**Input:**
```
Feature request: "Refactor the authentication module for better testability"
Context files: src/auth/login.py, src/auth/session.py
```

The skill provides context files to agents before they analyze.

### Example 3: Agent Failure Handling

**Scenario:** Bold-proposer agent times out during web research.

**Output:**
```
Warning: Agent execution failed:
- bold-proposer: Timeout after 5 minutes (web search exceeded limits)

You have 2/3 successful agent reports (critique, reducer).

Options:
1. Retry bold-proposer agent
2. Continue with 2 perspectives (critique + reducer only)
3. Abort debate

Your choice: _
```

## Integration Points

This skill is designed to be invoked by:
- **ultra-planner command**: Main user-facing interface
- **Other planning workflows**: Can be used standalone

This skill outputs to:
- **external-consensus skill**: Takes combined report as input
- **User review**: Combined report can be manually reviewed

## Notes

- All three agents run with **Opus model** for comprehensive analysis
- Agents run in **isolated contexts** (no shared state)
- Template substitution uses simple string replacement
- Output files in `.tmp/` are gitignored
- Execution time: Expect 3-8 minutes depending on complexity
- Cost: ~3x single planning cost (three Opus agents in parallel)
