---
name: ultra-planner
description: Multi-agent debate-based planning with /ultra-planner command
argument-hint: [feature-description] or --force-full [feature-description] or --refine [issue-no] [refine-comments] or --from-issue [issue-no]
---

ultrathink

# Ultra Planner Command

**IMPORTANT**: Keep a correct mindset when this command is invoked.

0. This workflow is intended to be as hands-off as possible, do your best
  - NOT TO STOP until the plan is finalized
  - NOT TO ask user for design decisions. Choose the one you think the most reasonable.
    If it is bad plan, user will feed it later.

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

Invoke the command: `/ultra-planner [feature-description]` or `/ultra-planner --refine [issue-no] [refine-comments]`

## What This Command Does

This command orchestrates a multi-agent debate system to generate high-quality implementation plans:

1. **Context gathering**: Launch understander agent to gather codebase context
2. **Three-agent debate**: Launch bold-proposer (with context) first, then critique and reducer analyze its output
3. **Combine reports**: Merge all three perspectives into single document
4. **External consensus**: Invoke external-consensus skill to synthesize balanced plan
5. **Draft issue creation**: Automatically create draft GitHub issue via open-issue skill

## Inputs

**This command only accepts feature descriptions for planning purposes. It does not execute implementation.**

**From arguments ($ARGUMENTS):**

- To avoid expanding ARGUMENTS multiple times, later we will use `{FEATURE_DESC}` to refer to it.

**Default mode:**
```
/ultra-planner Add user authentication with JWT tokens and role-based access control
```

**Refinement mode:**

```
/ultra-planner --refine <issue-no> <description>
```
- Refines an existing plan by running it through the debate system again

**From-issue mode:**

```
/ultra-planner --from-issue <issue-no>
```
- Creates a plan for an existing issue (typically a feature request)
- Reads the issue title and body as the feature description
- Updates the existing issue with the consensus plan (no new issue created)
- Used by the server for automatic feature request planning

**From conversation context:**
- If `$ARGUMENTS` is empty, extract feature description from recent messages
- Look for: "implement...", "add...", "create...", "build..." statements

## Outputs

**This command produces planning documents only. No code changes are made.**

**Files created:**
- `.tmp/issue-[refine-]{N}-context.md` - Understander context summary
- `.tmp/issue-[refine-]{N}-bold.md` - Bold proposer agent report
- `.tmp/issue-[refine-]{N}-critique.md` - Critique agent report
- `.tmp/issue-[refine-]{N}-reducer.md` - Reducer agent report
- `.tmp/issue-[refine-]{N}-debate.md` - Combined three-agent report
- `.tmp/issue-[refine-]{N}-consensus.md` - Final balanced plan

`[refine-]` is optional for refine mode.

**GitHub issue:**
- Created via open-issue skill if user approves

**Terminal output:**
- Debate summary from all three agents
- Consensus plan summary
- GitHub issue URL (if created)

## Workflow

### Step 1: Parse Arguments and Extract Feature Description

Accept the $ARGUMENTS.

**Force-full mode:** If we have `--force-full` at the beginning, skip complexity-based routing and always use the full multi-agent debate path. Remove `--force-full` from the arguments and proceed with the remaining feature description.

**Refinement mode:** If we have `--refine` at the beginning, the next number is the issue number to be refined,
and the rest are issue refine comments. You should fetch the issue to incorporate the users comments.
```bash
gh issue view <issue-no>
```

**From-issue mode:** If we have `--from-issue` at the beginning, the next number is the issue number to plan.
Fetch the issue title and body to use as the feature description:
```bash
gh issue view <issue-no> --json title,body
```
In this mode:
- The issue number is saved for Step 3 (skip placeholder creation, use existing issue)
- The feature description is extracted from the issue title and body
- After consensus, update the existing issue instead of creating a new one

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

### Step 3: Create Placeholder Issue (or use existing issue for --from-issue mode)

**For `--from-issue` mode:**
Skip placeholder creation. Use the issue number from Step 1 as `ISSUE_NUMBER` for all artifact filenames.

**For default mode (new feature):**

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

**Use `ISSUE_NUMBER` for all artifact filenames going forward** (Steps 4-8).

**Error handling:**
- If placeholder creation fails, stop execution and report error (cannot proceed without issue number)

### Step 4: Invoke Understander Agent

**REQUIRED TOOL CALL (before routing decision):**

Use the Task tool to launch the understander agent to gather codebase context:

```
Task tool parameters:
  subagent_type: "agentize:understander"
  prompt: "Gather codebase context for the following feature request: {FEATURE_DESC}"
  description: "Gather codebase context"
  model: "sonnet"
```

**Wait for agent completion** (blocking operation, do not proceed until done).

**Extract output:**
- Generate filename: `CONTEXT_FILE=".tmp/issue-${ISSUE_NUMBER}-context.md"`
- Save the agent's full response to `$CONTEXT_FILE`
- Also store in variable `UNDERSTANDER_OUTPUT` for passing to subsequent agents

**Parse complexity estimation:**
- Look for `**Recommended path**: \`lite\`` or `**Recommended path**: \`full\`` in the understander output
- Store as `RECOMMENDED_PATH` variable (either "lite" or "full")
- If pattern not found, default to "full"

### Step 4a: Route Based on Complexity (Lite vs Full Path)

**Lite path conditions** (ALL must be true):
1. All knowledge within repo (no internet research needed)
2. Less than 5 files affected
3. Less than 150 LOC total

**Check routing conditions:**

1. If `--force-full` flag was set in Step 1: **Use FULL path** (skip to Step 5)
2. If `--refine` mode: **Use FULL path** (refinements always use full debate)
3. If `RECOMMENDED_PATH == "lite"`: **Use LITE path** (go to Step 4b)
4. Otherwise: **Use FULL path** (go to Step 5)

**Output routing decision:**
```
Routing decision: {lite|full} path
Reason: {lite conditions met|force-full flag|refine mode|needs research or exceeds limits}
```

### Step 4b: Invoke Planner-Lite Agent (Lite Path Only)

**REQUIRED TOOL CALL (lite path only):**

Use the Task tool to launch the planner-lite agent:

```
Task tool parameters:
  subagent_type: "agentize:planner-lite"
  prompt: "Create an implementation plan for: {FEATURE_DESC}

CODEBASE CONTEXT (from understander):
{UNDERSTANDER_OUTPUT}

Use this context to create a focused, practical implementation plan."
  description: "Create lite plan"
  model: "sonnet"
```

**Wait for agent completion** (blocking operation).

**Extract output:**
- Generate filename: `LITE_PLAN_FILE=".tmp/issue-${ISSUE_NUMBER}-lite-plan.md"`
- Save the agent's full response to `$LITE_PLAN_FILE`

**After lite path completes:** Skip Steps 5, 6, AND 7 (no consensus needed with single agent). Proceed directly to Step 8 (Update Issue) using `$LITE_PLAN_FILE` as the consensus plan.

### Step 5: Invoke Bold-Proposer Agent

**REQUIRED TOOL CALL #1:**

Use the Task tool to launch the bold-proposer agent with understander context:

```
Task tool parameters:
  subagent_type: "agentize:bold-proposer"
  prompt: "Research and propose an innovative solution for: {FEATURE_DESC}

CODEBASE CONTEXT (from understander):
{UNDERSTANDER_OUTPUT}

Use this context as your starting point for understanding the codebase.
Focus your exploration on SOTA research and innovation."
  description: "Research SOTA solutions"
  model: "opus"
```

**Wait for agent completion** (blocking operation, do not proceed to Step 6 until done).

**Extract output:**
- Generate filename: `BOLD_FILE=".tmp/issue-${ISSUE_NUMBER}-bold-proposal.md"`
- Save the agent's full response to `$BOLD_FILE`
- Also store in variable `BOLD_PROPOSAL` for passing to critique and reducer agents in Step 6

### Step 6: Invoke Critique and Reducer Agents

**REQUIRED TOOL CALLS #2 & #3:**

**CRITICAL**: Launch BOTH agents in a SINGLE message with TWO Task tool calls to ensure parallel execution.

**Task tool call #1 - Critique Agent:**
```
Task tool parameters:
  subagent_type: "agentize:proposal-critique"
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
  subagent_type: "agentize:proposal-reducer"
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

### Step 7: Invoke External Consensus Skill (Full Path Only)

**REQUIRED SKILL CALL (full path only):**

The external-consensus skill synthesizes multiple debate perspectives into a balanced plan.

**For FULL path (after Steps 5-6):**
```
Skill tool parameters:
  skill: "external-consensus"
  args: "{BOLD_FILE} {CRITIQUE_FILE} {REDUCER_FILE}"
```

**For LITE path:** Skip this step entirely. With only one agent (planner-lite), there are no multiple perspectives to synthesize. Set `CONSENSUS_PLAN_FILE=$LITE_PLAN_FILE` and proceed directly to Step 8.

**Note:** The external-consensus skill will:
1. Combine the 3 agent reports into a single debate report (saved as `.tmp/issue-{N}-debate.md`)
2. Process through external AI review (Codex or Claude Opus)

NOTE: This consensus synthesis can take long time depending on the complexity of the debate report.
Give it 30 minutes timeout to complete, which is mandatory for **ALL DEBATES**!

**What this skill does:**
1. Combines the 3 agent reports into a single debate report (saved as `.tmp/issue-{N}-debate.md`)
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

To refine: /ultra-planner --refine ${ISSUE_NUMBER}
To implement: /issue-to-impl ${ISSUE_NUMBER}
```

### Step 9: Finalize Issue Labels

**REQUIRED BASH COMMAND:**

Add the "agentize:plan" label to mark the issue as a finalized plan:

```bash
gh issue edit ${ISSUE_NUMBER} --add-label "agentize:plan"
```

**For `--from-issue` mode only:** Also remove the "agentize:feat-request" label if present:

```bash
gh issue edit ${ISSUE_NUMBER} --remove-label "agentize:feat-request"
```

**What this does:**
1. Adds "agentize:plan" label to the issue (creates label if it doesn't exist)
2. Removes "agentize:feat-request" label (if from-issue mode) to prevent re-processing
3. Triggers hands-off state machine transition to `done` state
4. Marks the issue as ready for review/implementation

**Expected output:**
```
Label "agentize:plan" added to issue #${ISSUE_NUMBER}
```

Display the final output to the user. Command completes successfully.

## Usage Examples

### Example 1: Simple Feature (Lite Path)

**Input:**
```
/ultra-planner Add a helper function to format dates
```

**Output:**
```
Starting ultra-planner...

[Understander gathers context - 1-2 minutes]

Complexity estimation: ~50 LOC (Small)
Routing decision: lite path
Reason: understander recommended lite

[Planner-lite creates plan - 30-60 seconds]

Plan complete (no consensus needed - single agent)

Draft GitHub issue created: #42
Title: [plan][feat] Add date formatting helper
URL: https://github.com/user/repo/issues/42

To refine: /ultra-planner --refine 42
To implement: /issue-to-impl 42
```

### Example 2: Complex Feature (Full Path)

**Input:**
```
/ultra-planner Add user authentication with JWT tokens and role-based access control
```

**Output:**
```
Starting ultra-planner...

[Understander gathers context - 1-2 minutes]

Complexity estimation: ~350 LOC (Medium)
Routing decision: full path
Reason: understander recommended full

[Bold-proposer runs, then critique/reducer - 3-5 minutes]

Debate complete! Three perspectives:
- Bold: OAuth2 + JWT + RBAC (~450 LOC)
- Critique: High feasibility, 2 critical risks
- Reducer: Simple JWT only (~180 LOC)

External consensus review...

Consensus: JWT + basic roles (~280 LOC, Medium)
Path: full (multi-agent debate)

Draft GitHub issue created: #43
Title: [plan][feat] Add user authentication
URL: https://github.com/user/repo/issues/43

To refine: /ultra-planner --refine 43
To implement: /issue-to-impl 43
```

### Example 3: Force Full Debate

**Input:**
```
/ultra-planner --force-full Add a simple logging wrapper
```

**Output:**
```
Starting ultra-planner...

[Understander gathers context - 1-2 minutes]

Complexity estimation: ~80 LOC (Small)
Routing decision: full path
Reason: force-full flag

[Full debate runs despite low LOC estimate]
...
```

### Example 4: Plan Refinement

**Input:**
```
/ultra-planner --refine 42
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
