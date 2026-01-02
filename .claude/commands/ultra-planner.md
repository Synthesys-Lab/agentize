---
name: ultra-planner
description: Multi-agent debate-based planning with /ultra-planner command
argument-hint: [feature-description] or --refine [plan-file]
---

ultrathink

# Ultra Planner Command

**IMPORTANT**: This is a **planning tool only**. It takes a feature description as input and produces
a consensus implementation plan as output. It does NOT make any code changes or implement features.

**IMPORTANT**: No matter how simple you think the request is, always strictly follow the multi-agent
debase workflow below to do a thorough analysis of the request throughout the whole code base.
Sometimes what seems simple at first may have hidden complexities or breaking changes that
need to be uncovered via a debate.

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
/ultra-planner --refine .tmp/consensus-plan-20251225.md
```
- `$ARGUMENTS` = `--refine <plan-file>`
- Refines an existing plan by running it through the debate system again

**From conversation context:**
- If `$ARGUMENTS` is empty, extract feature description from recent messages
- Look for: "implement...", "add...", "create...", "build..." statements

## Outputs

**This command produces planning documents only. No code changes are made.**

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

### Step 3: Create Placeholder Draft Issue

**REQUIRED SKILL CALL (before agent execution):**

Create a placeholder draft issue to obtain the issue number for artifact naming:

```
Skill tool parameters:
  skill: "open-issue"
  args: "--draft --auto"
```

**Provide context to open-issue skill:**
- Feature description: `FEATURE_DESC`
- Issue body: "Placeholder for multi-agent planning in progress. This will be updated with the consensus plan."

**Extract issue number from response:**
```bash
# Expected output: "Draft GitHub issue created: #42"
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
as below:

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

Use the Skill tool to invoke the external-consensus skill:

```
Skill tool parameters:
  skill: "external-consensus"
  args: "{DEBATE_REPORT_FILE}"
```

**What this skill does:**
1. Reads the combined debate report from `DEBATE_REPORT_FILE`
2. Prepares external review prompt using `.claude/skills/external-consensus/external-review-prompt.md`
3. Invokes Codex CLI (preferred) or Claude API (fallback) for consensus synthesis
4. Parses and validates the consensus plan structure
5. Saves consensus plan to `.tmp/consensus-plan-{timestamp}.md`
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

Use the Skill tool to invoke the open-issue skill with update, draft, and auto flags:

```
Skill tool parameters:
  skill: "open-issue"
  args: "--update ${ISSUE_NUMBER} --draft --auto {CONSENSUS_PLAN_FILE}"
```

**What this skill does:**
1. Reads consensus plan from file
2. Determines appropriate tag from `docs/git-msg-tags.md`
3. Formats issue with `[draft]` prefix and Problem Statement/Proposed Solution sections
4. Updates existing issue #${ISSUE_NUMBER} (created in Step 3) using `gh issue edit`
5. Returns issue number and URL

**Expected output:**
```
Draft issue #${ISSUE_NUMBER} updated with consensus plan.

Title: [draft][plan][tag] {feature name}
URL: {issue_url}

This is a draft plan. To refine it, use:
  /refine-issue ${ISSUE_NUMBER}

To approve and implement, remove [draft] from the issue title on GitHub, then:
  /issue-to-impl ${ISSUE_NUMBER}
```

Display this output to the user. Command completes successfully.

## Error Handling

### Feature Description Missing

`FEATURE_DESC` is empty and no feature found in context.

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

### Agent Launch Failure

One or more agents fail to launch (e.g., agent not found, invalid configuration).

**Response:**
```
Error: Failed to launch agent(s):
- {agent-name}: {error-message}

Please ensure all debate agents are properly configured:
- .claude/agents/bold-proposer.md
- .claude/agents/proposal-critique.md
- .claude/agents/proposal-reducer.md
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
3. Abort debate and use /plan-an-issue instead
```

Wait for user decision.

### External Consensus Skill Failure

external-consensus skill fails (Codex/Claude unavailable or error).

**Response:**
```
Error: External consensus review failed.

Error from skill: {details}

Options:
1. Retry consensus review
2. Manually review debate report: {debate_report_file}
3. Use one agent's proposal directly (bold/critique/reducer)

The debate report contains all three perspectives.
```

Offer manual review fallback.

### Placeholder Issue Creation Failure (Step 3)

open-issue skill fails during placeholder creation.

**Response:**
```
Error: Failed to create placeholder draft issue.

Error: {details}

Cannot proceed without an issue number for artifact naming.

Please ensure:
1. GitHub CLI is authenticated: gh auth login
2. Repository has issues enabled
3. You have permission to create issues

Then retry: /ultra-planner {feature-description}
```

Stop execution (cannot proceed without issue number).

### Consensus Issue Update Failure (Step 8)

open-issue skill fails during update.

**Response:**
```
Error: Failed to update issue #${ISSUE_NUMBER} with consensus plan.

Error: {details}

The consensus plan is saved to: {consensus_plan_file}

You can:
1. Manually update issue #${ISSUE_NUMBER} on GitHub using the plan file
2. Create a new issue: /plan-an-issue {consensus_plan_file}
```

Provide plan file for manual update.

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

## Hands-Off Mode

**Enable auto-approval for safe operations** to reduce manual permission prompts during planning workflows.

**To enable:**
```bash
export CLAUDE_HANDSOFF=true
```

**To disable:**
```bash
export CLAUDE_HANDSOFF=false
```

**Safety boundaries:**
- Only safe/reversible operations auto-approved (reads, file writes on non-main branches)
- Destructive actions always require manual approval (git push, git reset, rm -rf)
- `.milestones/` files never auto-staged
- Only active on non-main branches

**Troubleshooting:**
- If workflow gets stuck: Check `.tmp/claude-hooks/auto-approvals.log` for decisions
- To force manual mode: Set `CLAUDE_HANDSOFF=false`

## Notes

- Bold-proposer runs first, then critique and reducer analyze its proposal in parallel
- Command directly orchestrates agents (no debate-based-planning skill needed)
- **external-consensus skill** is required for synthesis
- **open-issue skill** is used for GitHub issue creation with `--draft` and `--auto` flags
- Draft issues are created automatically (no user confirmation required)
- Refinement is now handled by `/refine-issue` command (updates existing issue)
- Plan files in `.tmp/` are **gitignored** (not tracked)
- Execution time: **5-10 minutes** end-to-end
- Cost: **~$2-5** per planning session (3 Opus agents + 1 external review)
- Best for: **Large to Very Large** features (≥400 LOC)
- Not for: **Small to Medium features** (<400 LOC) - use `/plan-an-issue` instead
