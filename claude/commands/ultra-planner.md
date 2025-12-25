---
name: ultra-planner
description: Multi-agent debate-based planning with /ultra-planner command
argument-hint: [feature-description] or --refine [plan-file]
---

# Ultra Planner Command

Create implementation plans through multi-agent debate, combining innovation, critical analysis, and simplification into a balanced consensus plan.

Invoke the command: `/ultra-planner [feature-description]` or `/ultra-planner --refine [plan-file]`

If arguments are provided via $ARGUMENTS, parse them as either:
- Feature description (default mode)
- `--refine <plan-file>` (refinement mode)

## What This Command Does

This command orchestrates a three-agent debate system to generate high-quality implementation plans:

1. **Three-agent debate**: Launch bold-proposer, proposal-critique, and proposal-reducer agents in parallel
2. **External consensus**: Synthesize balanced plan using Codex or Claude Opus
3. **User approval**: Present consensus plan for review
4. **GitHub issue creation**: Invoke open-issue skill to create [plan] issue

## Inputs

**From arguments ($ARGUMENTS):**

**Default mode:**
```
/ultra-planner Add user authentication with JWT tokens and role-based access control
```
- `$ARGUMENTS` = full feature description

**Refinement mode:**
```
/ultra-planner --refine .tmp/consensus-plan-20251225.md
```
- `$ARGUMENTS` = `--refine <plan-file>`
- Refines an existing plan by running it through the debate system again

**From conversation context:**
- If `$ARGUMENTS` is empty, extract feature description from recent messages
- Look for: "implement...", "add...", "create...", "build..." statements

## Outputs

**Files created:**
- `.tmp/debate-report-{timestamp}.md` - Combined three-agent report
- `.tmp/consensus-plan-{timestamp}.md` - Final balanced plan

**GitHub issue:**
- Created via open-issue skill if user approves

**Terminal output:**
- Debate summary from all three agents
- Consensus plan summary
- GitHub issue URL (if created)

## Workflow

### Step 1: Parse Arguments

Check if `$ARGUMENTS` contains `--refine`:

```bash
if echo "$ARGUMENTS" | grep -q "^--refine"; then
    MODE="refine"
    PLAN_FILE=$(echo "$ARGUMENTS" | sed 's/--refine //')
else
    MODE="default"
    FEATURE_DESCRIPTION="$ARGUMENTS"
fi
```

**Default mode:**
- Use `$ARGUMENTS` as feature description
- If empty, extract from conversation context

**Refinement mode:**
- Load existing plan from `$PLAN_FILE`
- Validate file exists
- Use plan content as feature description for debate

### Step 2: Validate Feature Description

Ensure feature description is clear and complete:

**Check:**
- Non-empty (minimum 10 characters)
- Describes what to build (not just "add feature")
- Provides enough context for agents to analyze

**If unclear:**
```
The feature description is unclear or too brief.

Current description: {description}

Please provide more details:
- What functionality are you adding?
- What problem does it solve?
- Any specific requirements or constraints?
```

Ask user for clarification.

### Step 3: Invoke Debate-Based Planning Skill

Launch the debate workflow:

**Skill:** `debate-based-planning`

**Inputs:**
- Feature request: `$FEATURE_DESCRIPTION`
- Context files: (optional, can be provided if relevant codebase files identified)
- Output path: `.tmp/debate-report-{timestamp}.md`

**Skill behavior:**
1. Launches three agents in parallel (bold-proposer, proposal-critique, proposal-reducer)
2. Each agent analyzes the feature independently
3. Combines all three reports into single document
4. Returns combined report path

**Expected output:**
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

Combined report saved to: {file}
```

### Step 4: Display Debate Summary to User

Show user the key points from each agent:

```
Multi-Agent Debate Complete
============================

BOLD PROPOSER (Innovation):
{summary of bold proposal}

CRITIQUE (Risk Analysis):
{summary of critical concerns}

REDUCER (Simplification):
{summary of simplifications}

Proceeding to external consensus review...
```

### Step 5: Invoke External Consensus Skill

Synthesize final plan from debate report:

**Skill:** `external-consensus`

**Inputs:**
- Combined report file: (from step 3)
- Feature name: Extract from description (first 5 words)
- Feature description: `$FEATURE_DESCRIPTION`

**Skill behavior:**
1. Loads combined debate report
2. Prepares external review prompt
3. Invokes Codex CLI (or Claude Opus fallback)
4. Parses and validates consensus plan
5. Saves plan to `.tmp/consensus-plan-{timestamp}.md`

**Expected output:**
```
External consensus review complete!

Consensus Plan Summary:
- Feature: {feature_name}
- Total LOC: ~{N} ({complexity})
- Components: {count}
- Critical risks: {risk_count}

Key Decisions:
- From Bold Proposal: {accepted_innovations}
- From Critique: {risks_addressed}
- From Reducer: {simplifications_applied}

Consensus plan saved to: {output_file}
```

### Step 6: Present Plan to User for Approval

Display the consensus plan and ask for approval:

```
Consensus Implementation Plan
==============================

{display key sections from consensus plan}

Total LOC: ~{N} ({complexity})
Components: {count}
Test strategy: {summary}

Full plan saved to: {file}

Options:
1. Approve and create GitHub issue
2. Refine plan (run /ultra-planner --refine {file})
3. Abandon plan

Your choice: _
```

**Wait for user decision.**

### Step 7A: If Approved - Create GitHub Issue

Invoke open-issue skill:

**Skill:** `open-issue`

**Inputs:**
- Plan file: Consensus plan from step 5
- Issue title: Extract from consensus plan
- Issue body: Use standard [plan] format with consensus plan as "Proposed Solution"

**Skill behavior:**
1. Reads consensus plan
2. Determines appropriate tag from `docs/git-msg-tags.md`
3. Formats issue with Problem Statement and Proposed Solution
4. Creates issue via `gh issue create`
5. Returns issue URL

**Output:**
```
GitHub issue created: #{issue_number}

Title: [plan][tag] {feature name}
URL: {issue_url}

Next steps:
- Review issue on GitHub
- Use /issue-to-impl {issue_number} to start implementation
```

Command completes successfully.

### Step 7B: If Refine - Restart with Existing Plan

User chooses to refine the plan:

```
Refining plan...

Use: /ultra-planner --refine {consensus_plan_file}
```

The plan file becomes input for a new debate cycle. The three agents will analyze the existing plan and propose improvements.

### Step 7C: If Abandoned - Exit

User abandons the plan:

```
Plan abandoned.

Debate report saved to: {debate_report_file}
Consensus plan saved to: {consensus_plan_file}

You can review these files later or restart with /ultra-planner.
```

Command exits without creating issue.

## Error Handling

### Feature Description Missing

`$ARGUMENTS` is empty and no feature found in context.

**Response:**
```
Error: No feature description provided.

Usage:
  /ultra-planner <feature-description>
  /ultra-planner --refine <plan-file>

Example:
  /ultra-planner Add user authentication with JWT tokens
```

Ask user to provide description.

### Refinement File Not Found

`--refine` mode but plan file doesn't exist.

**Response:**
```
Error: Plan file not found: {file}

Please provide a valid plan file path.

Available plans:
{list .tmp/consensus-plan-*.md files}
```

Show available plan files.

### Debate Skill Failure

One or more agents fail during debate.

**Response:**
```
Error: Debate-based planning failed.

Failed agents: {list}
Error details: {errors}

You can:
1. Retry /ultra-planner with the same description
2. Use /make-a-plan for single-agent planning instead
```

Offer fallback to regular planning.

### External Consensus Failure

External reviewer (Codex/Claude) unavailable or fails.

**Response:**
```
Error: External consensus review failed.

Error: {details}

Options:
1. Retry consensus review
2. Manually review debate report: {debate_report_file}
3. Use one agent's proposal directly (bold/critique/reducer)

The debate report contains all three perspectives.
```

Offer manual review fallback.

### GitHub Issue Creation Failure

open-issue skill fails.

**Response:**
```
Error: GitHub issue creation failed.

Error: {details}

The consensus plan is saved to: {consensus_plan_file}

You can:
1. Retry issue creation: /plan-an-issue {consensus_plan_file}
2. Create issue manually using the plan file
```

Provide plan file for manual issue creation.

## Usage Examples

### Example 1: Basic Feature Planning

**Input:**
```
/ultra-planner Add user authentication with JWT tokens and role-based access control
```

**Output:**
```
Starting multi-agent debate...

[Agents run in parallel]

Debate complete! Three perspectives:
- Bold: OAuth2 + JWT + RBAC (~450 LOC)
- Critique: High feasibility, 2 critical risks
- Reducer: Simple JWT only (~180 LOC)

External consensus review...

Consensus: JWT + basic roles (~280 LOC, Medium)

Approve and create GitHub issue? (y/n): y

GitHub issue created: #42
URL: https://github.com/user/repo/issues/42

Next: /issue-to-impl 42
```

### Example 2: Plan Refinement

**Input:**
```
/ultra-planner --refine .tmp/consensus-plan-20251225-160245.md
```

**Output:**
```
Refinement mode: Loading existing plan...

Running debate on current plan to identify improvements...

[Debate completes]

Refined consensus plan:
- Reduced LOC: 280 → 210 (25% reduction)
- Removed: OAuth2 integration
- Added: Better error handling

Approve refined plan? (y/n): y

GitHub issue created: #43 (refined plan)
```

### Example 3: Abandonment

**Input:**
```
/ultra-planner Build a complete e-commerce platform
```

**Output:**
```
Debate complete.

Consensus: ~2400 LOC (Very Large)

This is a very large feature. Consider breaking it down.

Approve? (y/n): n

Plan abandoned.

Saved files:
- Debate report: .tmp/debate-report-20251225-160530.md
- Consensus plan: .tmp/consensus-plan-20251225-160845.md

Tip: Review the debate report for insights on how to break this down.
```

## Notes

- Three agents run in **parallel** (faster than sequential)
- External reviewer is **required** (not optional)
- Refinement mode **reruns full debate** (not just consensus)
- Plan files in `.tmp/` are **gitignored** (not tracked)
- Execution time: **5-10 minutes** end-to-end
- Cost: **~$2-5** per planning session (3 Opus agents + 1 external review)
- Best for: **Medium to Very Large** features (>200 LOC)
- Not for: **Trivial changes** (<50 LOC) - use `/make-a-plan` instead
