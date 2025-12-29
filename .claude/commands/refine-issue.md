---
name: refine-issue
description: Refine GitHub plan issues using multi-agent debate workflow
argument-hint: <issue-number>
---

ultrathink

# Refine Issue Command

Refine existing GitHub plan issues by running the issue body through the multi-agent debate workflow and updating the issue with the improved plan.

Invoke the command: `/refine-issue <issue-number>`

## What This Command Does

This command fetches an existing GitHub plan issue, runs its content through the ultra-planner debate workflow, and updates the issue with the refined consensus plan:

1. **Fetch issue**: Get issue title and body via GitHub CLI
2. **Extract plan**: Save issue body to temporary file
3. **Run debate**: Invoke ultra-planner in refine mode with the plan
4. **Update issue**: Replace issue body with refined consensus plan

## Inputs

**From arguments ($ARGUMENTS):**
- Issue number (required): `$ARGUMENTS` = issue number to refine

**From conversation context:**
- If `$ARGUMENTS` is empty, extract issue number from recent messages
- Look for: "issue #123", "refine #45", etc.

**From GitHub:**
- Issue title and body via `gh issue view {N} --json title,body,state`

## Outputs

**Files created:**
- `.tmp/issue-{N}-original.md` - Original issue body
- `.tmp/debate-report-{timestamp}.md` - Combined three-agent report
- `.tmp/consensus-plan-{timestamp}.md` - Refined consensus plan

**GitHub issue:**
- Updated via `gh issue edit {N} --body-file` with refined plan

**Terminal output:**
- Debate summary from all three agents
- Consensus plan comparison (before/after LOC, changes)
- GitHub issue URL

## Workflow

### Step 1: Parse Arguments and Extract Issue Number

Parse $ARGUMENTS to get the issue number:

```bash
ISSUE_NUMBER="$ARGUMENTS"

if [ -z "$ISSUE_NUMBER" ]; then
    echo "Error: Issue number not provided."
    echo "Usage: /refine-issue <issue-number>"
    exit 1
fi
```

If empty, extract from conversation context looking for patterns like "issue #123" or "#45".

### Step 2: Fetch Issue from GitHub

Fetch the issue details:

```bash
ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --json title,body,state)
ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_JSON" | jq -r '.body')
ISSUE_STATE=$(echo "$ISSUE_JSON" | jq -r '.state')
```

**Validate:**
- Issue exists (non-zero exit code from gh)
- Issue is a plan issue (title contains `[plan]` or `[draft][plan]`)
- Issue state (warn if CLOSED)

### Step 3: Save Issue Body to Temporary File

Save the issue body for the debate workflow:

```bash
ORIGINAL_PLAN_FILE=".tmp/issue-${ISSUE_NUMBER}-original-$(date +%Y%m%d-%H%M%S).md"
echo "$ISSUE_BODY" > "$ORIGINAL_PLAN_FILE"
```

Display summary to user:
```
Fetching issue #${ISSUE_NUMBER}...

Title: ${ISSUE_TITLE}
Current plan size: $(echo "$ISSUE_BODY" | wc -l) lines

Starting refinement via multi-agent debate...
```

### Step 4: Invoke Ultra-Planner in Refine Mode

**CRITICAL:** Use the Task tool (NOT Skill tool) to run ultra-planner workflow:

The ultra-planner is a **command**, not a skill. Commands cannot invoke other commands directly. Therefore, this step must orchestrate the same debate workflow that ultra-planner uses, but without the final issue creation step.

**Substep 4A: Invoke Bold-Proposer Agent**

Use the Task tool to launch the bold-proposer agent:

```
Task tool parameters:
  subagent_type: "bold-proposer"
  prompt: "Review and improve this implementation plan:

{ISSUE_BODY}

Propose innovative improvements, identify missing components, and suggest better approaches."
  description: "Research improvements"
  model: "opus"
```

Save output to `BOLD_FILE=".tmp/bold-proposal-$(date +%Y%m%d-%H%M%S).md"`

**Substep 4B: Invoke Critique and Reducer Agents in Parallel**

Launch BOTH agents in a SINGLE message with TWO Task tool calls:

```
Task tool call #1 - Critique Agent:
  subagent_type: "proposal-critique"
  prompt: "Analyze this plan and the bold proposer's improvements:

Original Plan:
{ISSUE_BODY}

Proposed Improvements:
{BOLD_PROPOSAL}

Identify risks, validate assumptions, and assess feasibility."
  description: "Critique improvements"
  model: "opus"

Task tool call #2 - Reducer Agent:
  subagent_type: "proposal-reducer"
  prompt: "Simplify this plan using 'less is more' philosophy:

Original Plan:
{ISSUE_BODY}

Bold Proposer's Improvements:
{BOLD_PROPOSAL}

Identify unnecessary complexity and propose simpler alternatives."
  description: "Simplify improvements"
  model: "opus"
```

Save outputs to `CRITIQUE_FILE` and `REDUCER_FILE`

**Substep 4C: Combine Agent Reports**

Create debate report (same format as ultra-planner Step 5):

```bash
DEBATE_REPORT_FILE=".tmp/debate-report-$(date +%Y%m%d-%H%M%S).md"

{
    echo "# Multi-Agent Debate Report (Refinement)"
    echo ""
    echo "**Original Issue**: #${ISSUE_NUMBER}"
    echo "**Title**: ${ISSUE_TITLE}"
    echo "**Generated**: $(date +"%Y-%m-%d %H:%M")"
    echo ""
    # ... (same structure as ultra-planner)
    cat "$BOLD_FILE"
    # ...
    cat "$CRITIQUE_FILE"
    # ...
    cat "$REDUCER_FILE"
} > "$DEBATE_REPORT_FILE"
```

**Substep 4D: Invoke External Consensus Skill**

Use the Skill tool:

```
Skill tool parameters:
  skill: "external-consensus"
  args: "{DEBATE_REPORT_FILE}"
```

Extract consensus plan file path as `CONSENSUS_PLAN_FILE`

### Step 5: Update GitHub Issue

Update the issue with the refined plan:

```bash
gh issue edit "$ISSUE_NUMBER" --body-file "$CONSENSUS_PLAN_FILE"
```

**Preserve draft status:**
- If original title had `[draft]` prefix, keep it
- If not, don't add it

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

Issue title doesn't contain `[plan]` or `[draft][plan]`.

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

### Example 1: Basic Refinement

**Input:**
```
/refine-issue 42
```

**Output:**
```
Fetching issue #42...

Title: [draft][plan][feat] Add user authentication
Current plan size: 150 lines

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

### Example 2: Closed Issue Refinement

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

## Notes

- This command orchestrates the same three-agent debate as ultra-planner
- The refined plan replaces the entire issue body (Description + Proposed Solution sections)
- Original plan is saved to `.tmp/` for reference
- Refinement preserves the `[draft]` prefix if present
- Does NOT create a new issue - updates the existing one
- Execution time: **5-10 minutes** (same as ultra-planner)
- Cost: **~$2-5** per refinement (3 Opus agents + 1 external review)
