---
name: ultra-planner
description: Multi-agent debate-based planning with /ultra-planner command
argument-hint: [feature-description] or --refine [plan-file]
---

ultrathink

# Ultra Planner Command

**IMPORTANT**: Keep a correct mindset when this command is invoked.

1. This is a **planning tool only**. It takes a feature description as input and produces
a consensus implementation plan as output. It does NOT make any code changes or implement features.
Even if user is telling you "build...", "add...", "create...", "implement...", or "fix...",
you must interpret these as making a plan for how to have these achieved, not actually doing them!
  - **DO NOT** make any changes to the codebase!

2. This command uses a **multi-agent debate system** to generate high-quality plans.
**No matter** how simple you think the request is, always strictly follow the multi-agent
debase workflow below to do a thorough analysis of the request throughout the whole code base.
Sometimes what seems simple at first may have hidden complexities or breaking changes that
need to be uncovered via a debate and thorough codebase analysis.
  - **DO** follow the following multi-agent debate workflow exactly as specified.

Create implementation plans through multi-agent debate, combining innovation, critical analysis,
and simplification into a balanced consensus plan.

Invoke the command: `/ultra-planner [feature-description]` or `/ultra-planner --refine [plan-file]`

If arguments are provided via $ARGUMENTS, parse them as either:
- Feature description (default mode)
- `--refine <plan-file>` (refinement mode)

## What This Command Does

This command orchestrates a three-agent debate system to generate high-quality implementation plans:

1. **Three-agent debate**: Launch bold-proposer first, then critique and reducer analyze its output
2. **Combine reports**: Merge all three perspectives into single document
3. **External consensus**: Invoke external-consensus skill to synthesize balanced plan
4. **Draft issue creation**: Automatically create draft GitHub issue via open-issue skill

## Inputs

**This command only accepts feature descriptions for planning purposes. It does not execute implementation.**

**From arguments ($ARGUMENTS):**

**Default mode:**
```
/ultra-planner Add user authentication with JWT tokens and role-based access control
```
- `$ARGUMENTS` = full feature description (what to plan, not what to implement)

**Refinement mode:**
```
/ultra-planner --refine .tmp/issue-42-consensus.md
```
- `$ARGUMENTS` = `--refine <plan-file>`
- Refines an existing plan by running it through the debate system again

**From conversation context:**
- If `$ARGUMENTS` is empty, extract feature description from recent messages
- Look for: "implement...", "add...", "create...", "build..." statements

## Outputs

**This command produces planning documents only. No code changes are made.**

**Files created:**
- `.tmp/issue-{N}-debate.md` - Combined three-agent report
- `.tmp/issue-{N}-consensus.md` - Final balanced plan

**GitHub issue:**
- Created via open-issue skill if user approves

**Terminal output:**
- Debate summary from all three agents
- Consensus plan summary
- GitHub issue URL (if created)

## Workflow

### Step 1: Parse Arguments and Extract Feature Description

**IMPORTANT**: Parse $ARGUMENTS ONCE at the beginning and store in variables.

**Check for refinement mode:**
```bash
if echo "$ARGUMENTS" | grep -q "^--refine"; then
    MODE="refine"
    PLAN_FILE_PATH=$(echo "$ARGUMENTS" | sed 's/--refine //')
    # Load plan content into FEATURE_DESC
    if [ -f "$PLAN_FILE_PATH" ]; then
        FEATURE_DESC=$(cat "$PLAN_FILE_PATH")
    else
        echo "Error: Plan file not found: $PLAN_FILE_PATH"
        exit 1
    fi
else
    MODE="default"
    FEATURE_DESC="$ARGUMENTS"
fi
```

**Store these variables for the entire workflow:**
- `MODE`: Either "default" or "refine"
- `FEATURE_DESC`: The feature description (in default mode) or loaded from file (in refine mode)
- `PLAN_FILE_PATH`: Path to existing plan file (only in refine mode)

**Default mode:**
- Use `FEATURE_DESC` from $ARGUMENTS
- If empty, extract from conversation context

**Refinement mode:**
- Plan file content loaded into `FEATURE_DESC`
- File existence validated above

**DO NOT reference $ARGUMENTS again after this step.** Use `FEATURE_DESC` instead.

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

### Step 3: Create Placeholder Issue

**REQUIRED SKILL CALL (before agent execution):**

Create a placeholder issue to obtain the issue number for artifact naming:

```
Skill tool parameters:
  skill: "open-issue"
  args: "--auto"
```

**Provide context to open-issue skill:**
- Feature description: `FEATURE_DESC`
- Issue body: "Placeholder for multi-agent planning in progress. This will be updated with the consensus plan."

**Extract issue number from response:**
```bash
# Expected output: "GitHub issue created: #42"
ISSUE_URL=$(echo "$OPEN_ISSUE_OUTPUT" | grep -o 'https://[^ ]*')
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
```

**Use `ISSUE_NUMBER` for all artifact filenames going forward** (Steps 4-6).

**Error handling:**
- If placeholder creation fails, stop execution and report error (cannot proceed without issue number)

### Step 4: Invoke Bold-Proposer Agent

**REQUIRED TOOL CALL #1:**

Use the Task tool to launch the bold-proposer agent:

```
Task tool parameters:
  subagent_type: "bold-proposer"
  prompt: "Research and propose an innovative solution for: {FEATURE_DESC}"
  description: "Research SOTA solutions"
  model: "opus"
```

**Wait for agent completion** (blocking operation, do not proceed to Step 5 until done).

**Extract output:**
- Generate filename: `BOLD_FILE=".tmp/issue-${ISSUE_NUMBER}-bold-proposal.md"`
- Save the agent's full response to `$BOLD_FILE`
- Also store in variable `BOLD_PROPOSAL` for passing to critique and reducer agents in Step 5

### Step 5: Invoke Critique and Reducer Agents

**REQUIRED TOOL CALLS #2 & #3:**

**CRITICAL**: Launch BOTH agents in a SINGLE message with TWO Task tool calls to ensure parallel execution.

**Task tool call #1 - Critique Agent:**
```
Task tool parameters:
  subagent_type: "proposal-critique"
  prompt: "Analyze the following proposal for feasibility and risks:

Feature: {FEATURE_DESC}

Proposal from Bold-Proposer:
{BOLD_PROPOSAL}

Provide critical analysis of assumptions, risks, and feasibility."
  description: "Critique bold proposal"
  model: "opus"
```

**Task tool call #2 - Reducer Agent:**
```
Task tool parameters:
  subagent_type: "proposal-reducer"
  prompt: "Simplify the following proposal using 'less is more' philosophy:

Feature: {FEATURE_DESC}

Proposal from Bold-Proposer:
{BOLD_PROPOSAL}

Identify unnecessary complexity and propose simpler alternatives."
  description: "Simplify bold proposal"
  model: "opus"
```

**Wait for both agents to complete** (blocking operation).

**Extract outputs:**
- Generate filename: `CRITIQUE_FILE=".tmp/issue-${ISSUE_NUMBER}-critique.md"`
- Save critique agent's response to `$CRITIQUE_FILE`
- Generate filename: `REDUCER_FILE=".tmp/issue-${ISSUE_NUMBER}-reducer.md"`
- Save reducer agent's response to `$REDUCER_FILE`

**Expected agent outputs:**
- Bold proposer: Innovative proposal with SOTA research
- Critique: Risk analysis and feasibility assessment of Bold's proposal
- Reducer: Simplified version of Bold's proposal with complexity analysis

### Step 6: Combine Agent Reports

After all three agents complete, **DO NOT** even try to read their outputs!
Use `cat` and `heredoc` to combine their outputs into a single debate report
as below.

**IMPORTANT:** Use `.tmp/issue-{N}-debate.md` naming for the debate report to enable issue-number invocation of external-consensus.

**Generate combined report:**
```bash
FEATURE_NAME=$(echo "$FEATURE_DESC" | head -c 50)
DATETIME=$(date +"%Y-%m-%d %H:%M")
DEBATE_REPORT_FILE=".tmp/issue-${ISSUE_NUMBER}-debate.md"

{
    echo "# Multi-Agent Debate Report"
    echo ""
    echo "**Feature**: $FEATURE_NAME"
    echo "**Generated**: $DATETIME"
    echo ""
    echo "This document combines three perspectives from our multi-agent debate-based planning system:"
    echo "1. **Bold Proposer**: Innovative, SOTA-driven approach"
    echo "2. **Proposal Critique**: Feasibility analysis and risk assessment"
    echo "3. **Proposal Reducer**: Simplified, \"less is more\" approach"
    echo ""
    echo "---"
    echo ""
    echo "## Part 1: Bold Proposer Report"
    echo ""
    cat "$BOLD_FILE"
    echo ""
    echo "---"
    echo ""
    echo "## Part 2: Proposal Critique Report"
    echo ""
    cat "$CRITIQUE_FILE"
    echo ""
    echo "---"
    echo ""
    echo "## Part 3: Proposal Reducer Report"
    echo ""
    cat "$REDUCER_FILE"
    echo ""
    echo "---"
    echo ""
    echo "## Next Steps"
    echo ""
    echo "This combined report will be reviewed by an external consensus agent (Codex or Claude Opus) to synthesize a final, balanced implementation plan."
} > "$DEBATE_REPORT_FILE.tmp"
mv "$DEBATE_REPORT_FILE.tmp" "$DEBATE_REPORT_FILE"
```

**Note on filename consistency:** All filenames use the `issue-${ISSUE_NUMBER}-` prefix to enable tracing of artifacts back to the GitHub issue. This also ensures all artifacts for a given issue are grouped together in `.tmp/` directory.

### Step 7: Invoke External Consensus Skill

**REQUIRED SKILL CALL:**

Use the Skill tool to invoke the external-consensus skill with issue number:

```
Skill tool parameters:
  skill: "external-consensus"
  args: "{ISSUE_NUMBER}"
```

Note: The skill will resolve `.tmp/issue-{N}-debate.md` from the issue number (created in Step 6).

NOTE: This consensus synthesis can take long time depending on the complexity of the debate report.
Give it 30 minutes timeout to complete, which is mandatory for **ALL DEBATES**!

**What this skill does:**
1. Reads the combined debate report from `DEBATE_REPORT_FILE`
2. Prepares external review prompt using `.claude/skills/external-consensus/external-review-prompt.md`
3. Invokes Codex CLI (preferred) or Claude API (fallback) for consensus synthesis
4. Parses and validates the consensus plan structure
5. Saves consensus plan to `.tmp/issue-{N}-consensus.md`
6. Returns summary and file path

**Expected output structure from skill:**
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

Consensus plan saved to: {CONSENSUS_PLAN_FILE}
```

**Extract:**
- Save the consensus plan file path as `CONSENSUS_PLAN_FILE`

### Step 8: Update Placeholder Issue with Consensus Plan

**REQUIRED SKILL CALL:**

Use the Skill tool to invoke the open-issue skill with update and auto flags:

```
Skill tool parameters:
  skill: "open-issue"
  args: "--update ${ISSUE_NUMBER} --auto {CONSENSUS_PLAN_FILE}"
```

**What this skill does:**
1. Reads consensus plan from file
2. Determines appropriate tag from `docs/git-msg-tags.md`
3. Formats issue with `[plan]` prefix and Problem Statement/Proposed Solution sections
4. Updates existing issue #${ISSUE_NUMBER} (created in Step 3) using `gh issue edit`
5. Returns issue number and URL

**Expected output:**
```
Plan issue #${ISSUE_NUMBER} updated with consensus plan.

Title: [plan][tag] {feature name}
URL: {issue_url}

To refine: /refine-issue ${ISSUE_NUMBER}
To implement: /issue-to-impl ${ISSUE_NUMBER}
```

Display this output to the user. Command completes successfully.

## Usage Examples

### Example 1: Basic Feature Planning

**Input:**
```
/ultra-planner Add user authentication with JWT tokens and role-based access control
```

**Output:**
```
Starting multi-agent debate...

[Bold-proposer runs, then critique/reducer - 3-5 minutes]

Debate complete! Three perspectives:
- Bold: OAuth2 + JWT + RBAC (~450 LOC)
- Critique: High feasibility, 2 critical risks
- Reducer: Simple JWT only (~180 LOC)

External consensus review...

Consensus: JWT + basic roles (~280 LOC, Medium)

Draft GitHub issue created: #42
Title: [draft][plan][feat] Add user authentication
URL: https://github.com/user/repo/issues/42

To refine: /refine-issue 42
To implement: Remove [draft] on GitHub, then /issue-to-impl 42
```

### Example 2: Plan Refinement (Using /refine-issue)

**Note:** Plan refinement is now handled by the `/refine-issue` command, not `--refine` mode.

**Input:**
```
/refine-issue 42
```

**Output:**
```
Fetching issue #42...
Running debate on current plan to identify improvements...

[Debate completes]

Refined consensus plan:
- Reduced LOC: 280 → 210 (25% reduction)
- Removed: OAuth2 integration
- Added: Better error handling

Issue #42 updated with refined plan.
URL: https://github.com/user/repo/issues/42
```
