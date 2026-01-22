---
name: mega-planner
description: Multi-agent debate-based planning with dual proposers (bold + paranoia) and partial consensus
argument-hint: [feature-description] or --refine [issue-no] [refine-comments] or --from-issue [issue-no] or --resolve [issue-no] [selections]
---

# Mega Planner Command

**IMPORTANT**: Keep a correct mindset when this command is invoked.

0. This workflow distinguishes between **workflow autonomy** and **design arbitration**:
  - **Workflow autonomy**: DO NOT STOP the multi-agent debate workflow. Execute all steps (1-9) automatically without asking for permission to continue.
  - **Design arbitration**: DO NOT auto-resolve disagreements between agents. All contested design decisions MUST be exposed as Disagreement sections with options for developer selection.

  In practice:
  - NOT TO STOP workflow execution until the debate report and consensus options are generated
  - NOT TO autonomously drop ideas or resolve design disagreements. Present all options to the developer.
  - If agents disagree on any significant design choice, the plan MUST contain Disagreement sections requiring developer selection via `--resolve` mode

1. This is a **planning workflow**. It takes a feature description as input and produces
a consensus implementation plan as output. It does NOT make any code changes or implement features.
Even if user is telling you "build...", "add...", "create...", "implement...", or "fix...",
you must interpret these as making a plan for how to have these achieved, not actually doing them!
  - **DO NOT** make any changes to the codebase!

2. This command uses a **multi-agent debate system** to generate high-quality plans.
**No matter** how simple you think the request is, always strictly follow the multi-agent
debate workflow below to do a thorough analysis of the request throughout the whole code base.
Sometimes what seems simple at first may have hidden complexities or breaking changes that
need to be uncovered via a debate and thorough codebase analysis.
  - **DO** follow the following multi-agent debate workflow exactly as specified.

Create implementation plans through multi-agent debate, combining innovation, critical analysis,
and simplification into a balanced consensus plan.

Invoke the command: `/mega-planner [feature-description]` or `/mega-planner --refine [issue-no] [refine-comments]`

## What This Command Does

This command orchestrates a multi-agent debate system to generate high-quality implementation plans:

1. **Context gathering**: Launch understander agent to gather codebase context
2. **Dual proposer debate**: Launch bold-proposer and paranoia-proposer in parallel
3. **Three-agent analysis**: Critique and two reducers analyze BOTH proposals
4. **Combine reports**: Merge all perspectives into single document
5. **Partial consensus**: Invoke partial-consensus skill to synthesize balanced plan (or options)
6. **Issue update**: Update GitHub issue with consensus plan via `gh issue edit`

## Inputs

**This command only accepts feature descriptions for planning purposes. It does not execute implementation.**

**Default mode:**
```
/mega-planner Add user authentication with JWT tokens and role-based access control
```

**Refinement mode:**
```
/mega-planner --refine <issue-no> <refine-comments>
```
- Refines an existing plan by running it through the debate system again

**From-issue mode:**
```
/mega-planner --from-issue <issue-no>
```
- Creates a plan for an existing issue (typically a feature request)
- Reads the issue title and body as the feature description
- Updates the existing issue with the consensus plan (no new issue created)
- Used by the server for automatic feature request planning

**Resolve mode (fast-path):**
```
/mega-planner --resolve <issue-no> <selections>
```
- Resolves disagreements in an existing plan without re-running the 5-agent debate
- `<selections>`: Option codes like `1B` or `1C,2A` (can also use natural language: "Option 1B for architecture")
- Reads existing 5 agent report files from `.tmp/`
- Invokes `partial-consensus` skill with appended user selections
- Skips Steps 2-6 (5-agent debate phase)
- Updates the existing issue with the resolved plan

**From conversation context:**
- If arguments is empty, extract feature description from recent messages
- Look for: "implement...", "add...", "create...", "build..." statements

## Outputs

**This command produces planning documents only. No code changes are made.**

**Files created:**
- `.tmp/issue-{N}-context.md` - Understander context summary
- `.tmp/issue-{N}-bold.md` - Bold proposer agent report (with code diff drafts)
- `.tmp/issue-{N}-paranoia.md` - Paranoia proposer agent report (with code diff drafts)
- `.tmp/issue-{N}-critique.md` - Critique agent report (analyzes both proposals)
- `.tmp/issue-{N}-proposal-reducer.md` - Proposal reducer report (simplifies both proposals)
- `.tmp/issue-{N}-code-reducer.md` - Code reducer report (reduces total code footprint)
- `.tmp/issue-{N}-debate.md` - Combined multi-agent report
- `.tmp/issue-{N}-history.md` - Selection and refine history (accumulated across iterations)
- `.tmp/issue-{N}-consensus.md` - Final plan (or plan options)
- `.tmp/issue-{N}-partial-review-input.md` - Input prompt sent to external AI reviewer
- `.tmp/issue-{N}-partial-review-output.txt` - Raw output from external AI reviewer

All modes use the same `issue-{N}` prefix for artifact files.

**GitHub issue:**
- Created or updated via `gh issue create/edit` commands

**Terminal output:**
- Debate summary from all agents
- Consensus plan summary
- GitHub issue URL (if created)

## Workflow

### Step 1: Parse Arguments and Extract Feature Description

Accept the $ARGUMENTS.

**Resolve mode (fast-path):** If `--resolve` is at the beginning:
1. Parse `ISSUE_NUMBER` (next argument) and `SELECTIONS` (remaining arguments)
2. Set `FILE_PREFIX="issue-${ISSUE_NUMBER}"`
3. Verify ALL 5 report files exist:
   - `.tmp/${FILE_PREFIX}-bold.md`
   - `.tmp/${FILE_PREFIX}-paranoia.md`
   - `.tmp/${FILE_PREFIX}-critique.md`
   - `.tmp/${FILE_PREFIX}-proposal-reducer.md`
   - `.tmp/${FILE_PREFIX}-code-reducer.md`
4. If any not found, error: "No debate reports found for issue #N. Run full planning first with `/mega-planner --from-issue N`"
5. Verify `.tmp/${FILE_PREFIX}-consensus.md` exists. If not found, error: "Local consensus file not found. Run full planning first with `/mega-planner --from-issue N`"
6. **Read issue and compare with local consensus file:**
   ```bash
   # Fetch current issue body and save to temp file
   gh issue view ${ISSUE_NUMBER} --json body -q '.body' > ".tmp/${FILE_PREFIX}-issue-body.md"

   # Check if files differ
   if ! diff -q ".tmp/${FILE_PREFIX}-consensus.md" ".tmp/${FILE_PREFIX}-issue-body.md" > /dev/null 2>&1; then
       # Files differ - AI will summarize and prompt user
       DIFF_DETECTED=true
   else
       # Files match - proceed with local version
       DIFF_DETECTED=false
   fi
   ```

   **If files differ** (DIFF_DETECTED=true), read both files and summarize the differences:
   - Use Read tool to read both `.tmp/${FILE_PREFIX}-consensus.md` and `.tmp/${FILE_PREFIX}-issue-body.md`
   - Summarize key differences in natural language (e.g., "GitHub version has additional section X", "Local version modified step Y")
   - Report which version appears more complete/recent

   Then use **AskUserQuestion** with options:
   - **Use local**: Proceed with local `.tmp/${FILE_PREFIX}-consensus.md`
   - **Use GitHub**: Copy issue body to local consensus file, then proceed
   - **Re-run full planning**: Abort and suggest `/mega-planner --from-issue ${ISSUE_NUMBER}`

   **If files match** (DIFF_DETECTED=false), proceed directly with resolve mode (no user prompt needed).
7. **Skip Steps 2-6 entirely** (no debate needed)
8. Jump directly to Step 7 with resolve mode instructions

**Refinement mode:** If `--refine` is at the beginning:
1. Parse `ISSUE_NUMBER` (next argument) and `REFINE_COMMENTS` (remaining arguments)
2. Fetch the issue: `gh issue view ${ISSUE_NUMBER} --json title,body`
3. Construct FEATURE_DESC by appending refine-comments to the original issue:

```
## Original Issue

{issue title}

{issue body}

---

## Refinement Request

{REFINE_COMMENTS}
```

This preserves the original context so downstream agents can verify alignment with initial requirements.

```bash
gh issue view ${ISSUE_NUMBER} --json title,body
```

Set refine mode variables for use in Step 7 (history recording is consolidated there):
- `IS_REFINE_MODE=true`
- `REFINE_COMMENTS` preserved from argument parsing

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

### Step 3: Create Placeholder Issue (or use existing issue for --from-issue / --refine mode)

**For `--from-issue` mode:**
Skip placeholder creation. Use the issue number from Step 1 as `ISSUE_NUMBER` for all artifact filenames.
Set `FILE_PREFIX="issue-${ISSUE_NUMBER}"`.

**For `--refine` mode:**
Skip placeholder creation. Use the issue number from Step 1 as `ISSUE_NUMBER` for all artifact filenames.
Set `FILE_PREFIX="issue-${ISSUE_NUMBER}"`.

**For default mode (new feature):**

**Create placeholder issue (before agent execution):**

Create a placeholder issue using `gh` CLI to obtain the issue number for artifact naming:
```bash
# Create placeholder issue
ISSUE_URL=$(gh issue create \
    --title "[plan] ${FEATURE_DESC}" \
    --body "Placeholder for multi-agent planning in progress. This will be updated with the consensus plan." \
    --label "agentize:plan")
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
FILE_PREFIX="issue-${ISSUE_NUMBER}"
```

**Use `FILE_PREFIX` for all artifact filenames going forward** (Steps 4-8).

**Error handling:**
- If placeholder creation fails, stop execution and report error (cannot proceed without issue number)

### Step 4: Invoke Understander Agent

**REQUIRED TOOL CALL:**

```
Task tool parameters:
  subagent_type: "agentize:understander"
  prompt: "Gather codebase context for the following feature request: {FEATURE_DESC}"
  description: "Gather codebase context"
  model: "sonnet"
```

**Wait for agent completion** (blocking operation, do not proceed until done).

**Extract output:**
- Generate filename: `CONTEXT_FILE=".tmp/${FILE_PREFIX}-context.md"`
- Save the agent's full response to `$CONTEXT_FILE`
- Also store in variable `UNDERSTANDER_OUTPUT` for passing to subsequent agents

### Step 5: Invoke Dual Proposers (Bold + Paranoia) in Parallel

**CRITICAL**: Launch BOTH proposers in a SINGLE message with TWO Task tool calls.

**Task tool call #1 - Bold Proposer:**
```
Task tool parameters:
  subagent_type: "mega-planner:bold-proposer"
  prompt: "Research and propose an innovative solution for: {FEATURE_DESC}

CODEBASE CONTEXT (from understander):
{UNDERSTANDER_OUTPUT}

IMPORTANT: Instead of LOC estimates, provide CODE DIFF DRAFTS for each component.
Use ```diff blocks to show proposed changes."
  description: "Research SOTA solutions"
  model: "opus"
```

**Task tool call #2 - Paranoia Proposer:**
```
Task tool parameters:
  subagent_type: "mega-planner:paranoia-proposer"
  prompt: "Critically analyze and propose a destructive refactoring solution for: {FEATURE_DESC}

CODEBASE CONTEXT (from understander):
{UNDERSTANDER_OUTPUT}

IMPORTANT: Instead of LOC estimates, provide CODE DIFF DRAFTS for each component.
Use ```diff blocks to show proposed changes."
  description: "Propose destructive refactoring"
  model: "opus"
```

**Wait for both agents to complete.**

**Extract outputs:**
- Generate filename: `BOLD_FILE=".tmp/${FILE_PREFIX}-bold.md"`
- Save bold proposer's full response to `$BOLD_FILE`
- Also store in variable `BOLD_PROPOSAL`
- Generate filename: `PARANOIA_FILE=".tmp/${FILE_PREFIX}-paranoia.md"`
- Save paranoia proposer's full response to `$PARANOIA_FILE`
- Also store in variable `PARANOIA_PROPOSAL`

### Step 6: Invoke Critique and Both Reducers in Parallel

**CRITICAL**: Launch ALL THREE agents in a SINGLE message with THREE Task tool calls.

**Task tool call #1 - Critique Agent:**
```
Task tool parameters:
  subagent_type: "mega-planner:proposal-critique"
  prompt: "Analyze BOTH proposals for feasibility and risks:

Feature: {FEATURE_DESC}

BOLD PROPOSAL:
{BOLD_PROPOSAL}

PARANOIA PROPOSAL:
{PARANOIA_PROPOSAL}

Compare both approaches and provide critical analysis."
  description: "Critique both proposals"
  model: "opus"
```

**Task tool call #2 - Proposal Reducer:**
```
Task tool parameters:
  subagent_type: "mega-planner:proposal-reducer"
  prompt: "Simplify BOTH proposals using 'less is more' philosophy:

Feature: {FEATURE_DESC}

BOLD PROPOSAL:
{BOLD_PROPOSAL}

PARANOIA PROPOSAL:
{PARANOIA_PROPOSAL}

Identify unnecessary complexity in both and propose simpler alternatives."
  description: "Simplify both proposals"
  model: "opus"
```

**Task tool call #3 - Code Reducer:**
```
Task tool parameters:
  subagent_type: "mega-planner:code-reducer"
  prompt: "Analyze code changes in BOTH proposals:

Feature: {FEATURE_DESC}

BOLD PROPOSAL:
{BOLD_PROPOSAL}

PARANOIA PROPOSAL:
{PARANOIA_PROPOSAL}

Focus on reducing total code footprint while allowing large changes."
  description: "Reduce code complexity"
  model: "opus"
```

**Wait for all three agents to complete.**

**Extract outputs:**
- Generate filename: `CRITIQUE_FILE=".tmp/${FILE_PREFIX}-critique.md"`
- Save critique agent's response to `$CRITIQUE_FILE`
- Generate filename: `PROPOSAL_REDUCER_FILE=".tmp/${FILE_PREFIX}-proposal-reducer.md"`
- Save proposal reducer's response to `$PROPOSAL_REDUCER_FILE`
- Generate filename: `CODE_REDUCER_FILE=".tmp/${FILE_PREFIX}-code-reducer.md"`
- Save code reducer's response to `$CODE_REDUCER_FILE`

### Step 7: Invoke Partial Consensus Skill

**History file management (for resolve and refine modes):**

Both `--resolve` and `--refine` modes record their operations in the history file.
This consolidates history management into a single location.

```bash
HISTORY_FILE=".tmp/${FILE_PREFIX}-history.md"
CONSENSUS_FILE=".tmp/${FILE_PREFIX}-consensus.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

# Initialize history file if not exists (unified single-table format)
if [ ! -f "$HISTORY_FILE" ]; then
    cat > "$HISTORY_FILE" <<EOF
# Selection & Refine History

| Timestamp | Type | Content |
|-----------|------|---------|
EOF
fi
```

**For resolve mode:**
```bash
# Append to unified history table
echo "| ${TIMESTAMP} | resolve | ${SELECTIONS} |" >> "$HISTORY_FILE"
```

**For refine mode:**
```bash
# Append to unified history table
REFINE_SUMMARY=$(echo "${REFINE_COMMENTS}" | head -c 80 | tr '\n' ' ')
echo "| ${TIMESTAMP} | refine | ${REFINE_SUMMARY} |" >> "$HISTORY_FILE"
```

Then invoke partial-consensus with consensus.md as 6th argument and history as 7th:

```
Skill tool parameters:
  skill: "partial-consensus"
  args: ".tmp/${FILE_PREFIX}-bold.md .tmp/${FILE_PREFIX}-paranoia.md .tmp/${FILE_PREFIX}-critique.md .tmp/${FILE_PREFIX}-proposal-reducer.md .tmp/${FILE_PREFIX}-code-reducer.md .tmp/${FILE_PREFIX}-consensus.md .tmp/${FILE_PREFIX}-history.md"
```

Continue to Step 8.

---

**For standard mode (full debate):**

**REQUIRED SKILL CALL:**

```
Skill tool parameters:
  skill: "partial-consensus"
  args: "{BOLD_FILE} {PARANOIA_FILE} {CRITIQUE_FILE} {PROPOSAL_REDUCER_FILE} {CODE_REDUCER_FILE}"
```

**What this skill does:**
1. Combines all 5 agent reports into a single debate report
2. Processes through external AI review
3. **If consensus reached**: Produces single balanced plan
4. **If no consensus**: Produces multiple plan options for user selection

**Expected outputs:**
- Debate report: `.tmp/${FILE_PREFIX}-debate.md`
- Consensus plan: `.tmp/${FILE_PREFIX}-consensus.md`

**Extract:**
- Save the consensus plan file path as `CONSENSUS_PLAN_FILE=".tmp/${FILE_PREFIX}-consensus.md"`

Give it 30 minutes timeout to complete.

### Step 8: Update Issue with Consensus Plan

**Direct shell command (preserves `<details>` blocks verbatim):**

**Why direct file path instead of pipe:**
- Pipe (`tail -n +2 | gh issue edit --body-file -`) is unreliable and may produce empty body
- Direct `--body-file <file>` is robust and preserves all content

```bash
# Update issue body directly from consensus file
gh issue edit ${ISSUE_NUMBER} --body-file "${CONSENSUS_PLAN_FILE}"
```

**If multiple plans were generated (no consensus):**
- Present all options to user in terminal
- Let user select preferred approach
- After selection, update issue with selected plan file using same command above

**Expected output:**
```
Plan issue #${ISSUE_NUMBER} updated with consensus plan.

URL: ${ISSUE_URL}

To refine: /mega-planner --refine ${ISSUE_NUMBER}
Next steps: Review the plan and begin implementation when ready.
```

### Step 9: Finalize Issue Labels

```bash
gh issue edit ${ISSUE_NUMBER} --add-label "agentize:plan"
```

**For `--from-issue` mode only:** Also remove the "agentize:feat-request" label if present:

```bash
gh issue edit ${ISSUE_NUMBER} --remove-label "agentize:feat-request"
```

**Expected output:**
```
Label "agentize:plan" added to issue #${ISSUE_NUMBER}
```

Display the final output to the user. Command completes successfully.

-------------

Follow the workflow and $ARGUMENT parsing above to make the plan.

$ARGUMENTS
