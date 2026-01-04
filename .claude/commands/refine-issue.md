---
name: refine-issue
description: Refine GitHub plan issues using multi-agent debate workflow
argument-hint: <issue-number> [refinement-instructions]
---

ultrathink

# Refine Issue Command

Refine existing GitHub plan issues by running the issue body through the multi-agent debate workflow and updating the issue with the improved plan.

Invoke the command: `/refine-issue <issue-number> [refinement-instructions]`

## What This Command Does

This command fetches an existing GitHub plan issue, runs its content through the ultra-planner debate workflow, and updates the issue with the refined consensus plan:

1. **Fetch issue**: Get issue title and body via GitHub CLI
2. **Invoke three-agent debate**: Bold-proposer, then critique and reducer in parallel
3. **Combine reports**: Merge all three perspectives into single document
4. **External consensus**: Synthesize balanced refinement from debate
5. **Update issue**: Replace issue body with refined consensus plan

## Inputs

**From arguments ($ARGUMENTS):**
- Issue number (required): First token in `$ARGUMENTS`
- Refinement instructions (optional): Remaining tokens after issue number

**Examples:**
```
/refine-issue 42
/refine-issue 42 Focus on reducing complexity
/refine-issue 42 Add more error handling and edge cases
```

**From conversation context:**
- If `$ARGUMENTS` is empty, extract issue number from recent messages
- Look for: "issue #123", "refine #45", etc.

**From GitHub:**
- Issue title and body via `gh issue view {N} --json title,body,state`

## Outputs

**Files created:**
- `.tmp/issue-{N}-original.md` - Original issue body
- `.tmp/issue-{N}-debate.md` - Combined three-agent report
- `.tmp/issue-{N}-consensus.md` - Refined consensus plan

**GitHub issue:**
- Updated via `gh issue edit {N} --body-file` with refined plan

**Terminal output:**
- Debate summary from all three agents
- Consensus plan comparison (before/after LOC, changes)
- GitHub issue URL

## Workflow

### Step 1: Parse Arguments and Extract Issue Number

**IMPORTANT**: Parse $ARGUMENTS ONCE at the beginning and store in variables.

```bash
ISSUE_NUMBER=$(echo "$ARGUMENTS" | awk '{print $1}')
REFINEMENT_INSTRUCTIONS=$(echo "$ARGUMENTS" | cut -d' ' -f2-)

# If only issue number provided, clear refinement instructions
if [ "$ISSUE_NUMBER" = "$REFINEMENT_INSTRUCTIONS" ]; then
    REFINEMENT_INSTRUCTIONS=""
fi
```

**Store these variables for the entire workflow:**
- `ISSUE_NUMBER`: The GitHub issue number to refine
- `REFINEMENT_INSTRUCTIONS`: Optional user-provided refinement focus (empty if not provided)

**Validation:**
```bash
if [ -z "$ISSUE_NUMBER" ]; then
    echo "Error: Issue number not provided."
    echo "Usage: /refine-issue <issue-number> [refinement-instructions]"
    echo ""
    echo "Examples:"
    echo "  /refine-issue 42"
    echo "  /refine-issue 42 Focus on reducing complexity"
    exit 1
fi
```

If empty, extract from conversation context looking for patterns like "issue #123" or "#45".

**DO NOT reference $ARGUMENTS again after this step.** Use `ISSUE_NUMBER` and `REFINEMENT_INSTRUCTIONS` instead.

### Step 2: Fetch and Validate Issue from GitHub

Fetch the issue details:

```bash
ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --json title,body,state)
ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_JSON" | jq -r '.body')
ISSUE_STATE=$(echo "$ISSUE_JSON" | jq -r '.state')
```

**Validate:**
- Issue exists (non-zero exit code from gh)
- Issue is a plan issue (title contains `[plan]`)
- Issue state (warn if CLOSED)

**Save original plan:**
```bash
ORIGINAL_PLAN_FILE=".tmp/issue-${ISSUE_NUMBER}-original-$(date +%Y%m%d-%H%M%S).md"
echo "$ISSUE_BODY" > "$ORIGINAL_PLAN_FILE"
```

Display summary to user:
```
Fetching issue #${ISSUE_NUMBER}...

Title: ${ISSUE_TITLE}
Current plan size: $(echo "$ISSUE_BODY" | wc -l) lines
Refinement focus: ${REFINEMENT_INSTRUCTIONS:-"General improvements"}

Starting refinement via multi-agent debate...
```

### Step 3: Invoke Bold-Proposer Agent

**REQUIRED TOOL CALL #1:**

Use the Task tool to launch the bold-proposer agent:

```
Task tool parameters:
  subagent_type: "bold-proposer"
  prompt: "Review and improve this implementation plan:

${REFINEMENT_INSTRUCTIONS:+User refinement request: $REFINEMENT_INSTRUCTIONS

}Original Plan:
$ISSUE_BODY

Propose innovative improvements, identify missing components, and suggest better approaches."
  description: "Research improvements"
  model: "opus"
```

**Wait for agent completion** (blocking operation, do not proceed to Step 4 until done).

**Extract output:**
- Generate filename: `BOLD_FILE=".tmp/bold-proposal-$(date +%Y%m%d-%H%M%S).md"`
- Save the agent's full response to `$BOLD_FILE`
- Also store in variable `BOLD_PROPOSAL` for passing to critique and reducer agents in Step 4

### Step 4: Invoke Critique and Reducer Agents

**REQUIRED TOOL CALLS #2 & #3:**

**CRITICAL**: Launch BOTH agents in a SINGLE message with TWO Task tool calls to ensure parallel execution.

**Task tool call #1 - Critique Agent:**
```
Task tool parameters:
  subagent_type: "proposal-critique"
  prompt: "Analyze the following proposal for feasibility and risks:

${REFINEMENT_INSTRUCTIONS:+User refinement request: $REFINEMENT_INSTRUCTIONS

}Original Plan:
$ISSUE_BODY

Proposal from Bold-Proposer:
$BOLD_PROPOSAL

Identify risks, validate assumptions, and assess feasibility."
  description: "Critique improvements"
  model: "opus"
```

**Task tool call #2 - Reducer Agent:**
```
Task tool parameters:
  subagent_type: "proposal-reducer"
  prompt: "Simplify the following proposal using 'less is more' philosophy:

${REFINEMENT_INSTRUCTIONS:+User refinement request: $REFINEMENT_INSTRUCTIONS

}Original Plan:
$ISSUE_BODY

Proposal from Bold-Proposer:
$BOLD_PROPOSAL

Identify unnecessary complexity and propose simpler alternatives."
  description: "Simplify improvements"
  model: "opus"
```

**Wait for both agents to complete** (blocking operation).

**Extract outputs:**
- Generate filename: `CRITIQUE_FILE=".tmp/critique-output-$(date +%Y%m%d-%H%M%S).md"`
- Save critique agent's response to `$CRITIQUE_FILE`
- Generate filename: `REDUCER_FILE=".tmp/reducer-output-$(date +%Y%m%d-%H%M%S).md"`
- Save reducer agent's response to `$REDUCER_FILE`

### Step 5: Combine Agent Reports

After all three agents complete, combine their outputs into a single debate report.

**IMPORTANT:** Use `.tmp/issue-{N}-debate.md` naming for the debate report to enable issue-number invocation of external-consensus.

**Generate combined report:**
```bash
DATETIME=$(date +"%Y-%m-%d %H:%M")
DEBATE_REPORT_FILE=".tmp/issue-${ISSUE_NUMBER}-debate.md"

{
    echo "# Multi-Agent Debate Report (Refinement)"
    echo ""
    echo "**Original Issue**: #${ISSUE_NUMBER}"
    echo "**Title**: ${ISSUE_TITLE}"
    echo "**Generated**: $DATETIME"
    if [ -n "$REFINEMENT_INSTRUCTIONS" ]; then
        echo "**Refinement Focus**: $REFINEMENT_INSTRUCTIONS"
    fi
    echo ""
    echo "This document combines three perspectives from our multi-agent debate-based refinement system:"
    echo "1. **Bold Proposer**: Innovative improvements and missing components"
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
    echo "This combined report will be reviewed by an external consensus agent to synthesize a final, balanced refinement plan."
} > "$DEBATE_REPORT_FILE.tmp"
mv "$DEBATE_REPORT_FILE.tmp" "$DEBATE_REPORT_FILE"
```

**Note on filename consistency:** The debate report uses `issue-${ISSUE_NUMBER}-debate.md` naming to enable issue-number invocation of external-consensus. Agent report files use timestamps to avoid conflicts across multiple refinements.

### Step 6: Invoke External Consensus Skill

**REQUIRED SKILL CALL:**

Use the Skill tool to invoke the external-consensus skill with issue number:

```
Skill tool parameters:
  skill: "external-consensus"
  args: "{ISSUE_NUMBER}"
```

Note: The skill will resolve `.tmp/issue-{N}-debate.md` from the issue number (created in Step 5).

**What this skill does:**
1. Reads the combined debate report from `DEBATE_REPORT_FILE`
2. Prepares external review prompt using `.claude/skills/external-consensus/external-review-prompt.md`
3. Invokes Codex CLI (preferred) or Claude API (fallback) for consensus synthesis
4. Parses and validates the consensus plan structure
5. Saves consensus plan to `.tmp/consensus-plan-{timestamp}.md`
6. Returns summary and file path

**Extract:**
- Save the consensus plan file path as `CONSENSUS_PLAN_FILE`

### Step 7: Update GitHub Issue

Update the issue with the refined plan:

```bash
gh issue edit "$ISSUE_NUMBER" --body-file "$CONSENSUS_PLAN_FILE"
```

Display summary to user:
```
Refinement complete!

Issue #${ISSUE_NUMBER} updated with refined plan.
URL: $(gh issue view "$ISSUE_NUMBER" --json url --jq '.url')

Summary of changes:
- Original LOC: {original_loc}
- Refined LOC: {refined_loc}
- Key improvements: {summary}
```

Command completes successfully.

## Error Handling

### Issue Number Missing

`$ARGUMENTS` is empty and no issue number found in context.

**Response:**
```
Error: Issue number not provided.

Usage: /refine-issue <issue-number>

Example:
  /refine-issue 42
```

Ask user to provide issue number.

### Issue Not Found

```bash
gh issue view {N}
# Exit code: non-zero
```

**Response:**
```
Error: Issue #{N} not found in this repository.

Please provide a valid issue number.
```

Stop execution.

### Issue Not a Plan Issue

Issue title doesn't contain `[plan]`.

**Response:**
```
Error: Issue #{N} is not a plan issue.

Title: {title}

The /refine-issue command is only for [plan] issues with implementation plans.
For other issues, edit them manually or create a new plan with /ultra-planner.
```

Stop execution.

### Issue Closed

Issue state is CLOSED.

**Response:**
```
Warning: Issue #{N} is CLOSED.

Continue refining a closed issue?
```

Wait for user confirmation before proceeding.

### GitHub CLI Not Authenticated

```bash
gh issue view {N}
# Error: authentication required
```

**Response:**
```
Error: GitHub CLI is not authenticated.

Run: gh auth login
```

Stop execution.

### Agent Execution Failure

One or more agents fail during debate.

**Response:**
```
Warning: Agent execution failed:
- {agent-name}: {error-message}

You have {N}/3 successful agent reports.

Options:
1. Retry failed agent: {agent-name}
2. Continue with partial results ({N} perspectives)
3. Abort refinement
```

Wait for user decision.

### External Consensus Skill Failure

external-consensus skill fails.

**Response:**
```
Error: External consensus review failed.

Error from skill: {details}

The original plan is saved to: {original_plan_file}
The debate report is saved to: {debate_report_file}

You can:
1. Retry consensus review
2. Manually update the issue with one of the agent proposals
```

Offer manual review fallback.

## Usage Examples

### Example 1: General Refinement

**Input:**
```
/refine-issue 42
```

**Output:**
```
Fetching issue #42...

Title: [plan][feat] Add user authentication
Current plan size: 150 lines
Refinement focus: General improvements

Starting refinement via multi-agent debate...

[Bold-proposer, critique, reducer run - 3-5 minutes]

Debate complete! Three perspectives:
- Bold: Add OAuth2 support (~350 LOC)
- Critique: Focus on security concerns
- Reducer: Simplify to JWT-only (~200 LOC)

External consensus review...

Refined consensus: JWT with improved security (~250 LOC)

Issue #42 updated with refined plan.
URL: https://github.com/user/repo/issues/42

Summary of changes:
- Original LOC: ~280
- Refined LOC: ~250 (11% reduction)
- Key improvements: Better error handling, improved security
```

### Example 2: Directed Refinement (Complexity Focus)

**Input:**
```
/refine-issue 42 Focus on reducing complexity
```

**Output:**
```
Fetching issue #42...

Title: [plan][feat] Add user authentication
Current plan size: 280 lines
Refinement focus: Focus on reducing complexity

Starting refinement via multi-agent debate...

[Agents incorporate user's refinement focus in their analysis]

Debate complete! Three perspectives focused on simplification:
- Bold: Remove OAuth2, JWT-only (~180 LOC)
- Critique: Identify complexity risks in current plan
- Reducer: Minimal viable auth (~120 LOC)

External consensus review...

Refined consensus: Simplified JWT implementation (~150 LOC)

Issue #42 updated with refined plan.
URL: https://github.com/user/repo/issues/42

Summary of changes:
- Original LOC: ~280
- Refined LOC: ~150 (46% reduction)
- Key improvements: Removed OAuth2, simplified middleware
```

### Example 3: Directed Refinement (Feature Addition)

**Input:**
```
/refine-issue 42 Add more error handling and edge cases
```

**Output:**
```
Fetching issue #42...

Title: [plan][feat] Add user authentication
Current plan size: 250 lines
Refinement focus: Add more error handling and edge cases

Starting refinement via multi-agent debate...

[Agents focus on robustness and edge cases]

Debate complete! Three perspectives on error handling:
- Bold: Comprehensive error scenarios (~320 LOC)
- Critique: Critical edge cases analysis
- Reducer: Essential error handling only (~280 LOC)

External consensus review...

Refined consensus: Balanced error handling (~290 LOC)

Issue #42 updated with refined plan.
URL: https://github.com/user/repo/issues/42

Summary of changes:
- Original LOC: ~250
- Refined LOC: ~290 (16% increase)
- Key improvements: Added token expiry, rate limiting, invalid credential handling
```

### Example 4: Closed Issue Refinement

**Input:**
```
/refine-issue 15
```

**Output:**
```
Fetching issue #15...

Warning: Issue #15 is CLOSED.

Continue refining a closed issue? (y/n): y

[Refinement proceeds as normal]
```
