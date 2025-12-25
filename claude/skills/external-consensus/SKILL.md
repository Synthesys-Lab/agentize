---
name: external-consensus
description: Synthesize consensus implementation plan from multi-agent debate reports using external AI review
---

# External Consensus Skill

This skill invokes an external AI reviewer (Codex or Claude Opus) to synthesize a balanced, consensus implementation plan from the combined multi-agent debate report.

## Skill Philosophy

After three agents debate a feature from different perspectives, an **external, neutral reviewer** synthesizes the final plan:

- **External = Unbiased**: Not influenced by any single perspective
- **Consensus = Balanced**: Incorporates best ideas from all agents
- **Actionable = Clear**: Produces ready-to-implement plan with specific steps

The external reviewer acts as a "tie-breaker" and "integrator" - resolving conflicts between agents and combining their insights into a coherent whole.

## Skill Overview

When invoked, this skill:

1. **Loads combined debate report**: Three-agent perspectives from debate-based-planning skill
2. **Prepares external review prompt**: Uses template with debate context
3. **Invokes external reviewer**: Calls Codex (preferred) or Claude Opus (fallback)
4. **Parses consensus plan**: Extracts structured implementation plan from response
5. **Returns final plan**: Ready for user approval and GitHub issue creation

## Inputs

This skill expects:
- **Combined report file**: Path to debate report (e.g., `.tmp/debate-report-20251225.md`)
- **Feature name**: Short name for the feature
- **Feature description**: Brief description of what user wants to build

## Outputs

- **Consensus plan file**: `.tmp/consensus-plan-{timestamp}.md` with final implementation plan
- **Plan summary**: Key decisions and LOC estimate

## Implementation Workflow

### Step 1: Validate Inputs

Check that all required inputs are provided:

```bash
# Combined report must exist
if [ ! -f "$COMBINED_REPORT_FILE" ]; then
    echo "Error: Combined report file not found: $COMBINED_REPORT_FILE"
    exit 1
fi

# Feature name and description must be non-empty
if [ -z "$FEATURE_NAME" ] || [ -z "$FEATURE_DESCRIPTION" ]; then
    echo "Error: Feature name and description are required"
    exit 1
fi
```

**Required inputs:**
- Path to combined debate report
- Feature name (for labeling)
- Feature description (for context)

### Step 2: Invoke External Review Script

Call the external review script with proper arguments:

```bash
./scripts/external-review.sh \
    "$COMBINED_REPORT_FILE" \
    "$FEATURE_NAME" \
    "$FEATURE_DESCRIPTION"
```

The script will:
1. Load prompt template from `.tmp/templates/external-review-prompt.md`
2. Substitute variables: `{{FEATURE_NAME}}`, `{{FEATURE_DESCRIPTION}}`, `{{COMBINED_REPORT}}`
3. Try Codex CLI first (if available)
4. Fallback to Claude Opus CLI (if Codex unavailable)
5. Return consensus plan on stdout

**Expected output format:**
```markdown
# Implementation Plan: {Feature Name}

## Consensus Summary

[Summary of balanced approach...]

## Design Decisions

[Decisions from each perspective...]

## Architecture

[Component descriptions...]

## Implementation Steps

[Detailed steps with LOC estimates...]

## Test Strategy

[Test approach and cases...]

## Success Criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Risks and Mitigations

[Risk table...]
```

### Step 3: Capture External Reviewer Output

Read the consensus plan from script stdout:

```bash
CONSENSUS_PLAN=$(./scripts/external-review.sh "$COMBINED_REPORT_FILE" "$FEATURE_NAME" "$FEATURE_DESCRIPTION")
EXIT_CODE=$?
```

**Error handling:**
- If exit code != 0, external review failed
- Check error message from script
- Provide fallback options to user

### Step 4: Validate Consensus Plan

Check that the output is a valid implementation plan:

**Basic validation:**
- Output is non-empty
- Contains required sections: "Implementation Plan", "Architecture", "Implementation Steps"
- Has LOC estimate in "Implementation Steps"

**Quality check:**
- Plan references decisions from all three perspectives (bold, critique, reducer)
- Includes specific file paths and components
- Has actionable implementation steps

If validation fails:
```
Warning: External reviewer output may be incomplete.

Missing sections: {list}

The consensus plan may need manual review before proceeding.

Continue anyway? (y/n)
```

### Step 5: Save Consensus Plan

Write the validated plan to output file:

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_FILE=".tmp/consensus-plan-$TIMESTAMP.md"
echo "$CONSENSUS_PLAN" > "$OUTPUT_FILE"
```

**File location**: `.tmp/consensus-plan-{timestamp}.md` (gitignored)

### Step 6: Extract Summary Information

Parse key information from consensus plan for user display:

**Extract:**
1. **Total LOC estimate**: Parse from "Implementation Steps" section
2. **Complexity rating**: Small/Medium/Large/Very Large
3. **Component count**: Number of major components
4. **Test strategy**: Brief summary from "Test Strategy" section
5. **Critical risks**: Count from "Risks and Mitigations" section

**Example parsing:**
```bash
# Extract total LOC
TOTAL_LOC=$(grep -A5 "Implementation Steps" "$OUTPUT_FILE" | grep -i "total" | grep -oP '~\K[0-9]+')

# Extract complexity
COMPLEXITY=$(grep -A5 "Implementation Steps" "$OUTPUT_FILE" | grep -oP '\(.*\)' | tail -n1)
```

### Step 7: Return Results

Output summary to user:

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

Next step: Review plan and create GitHub issue with open-issue skill.
```

## Error Handling

### Combined Report Not Found

Input file path doesn't exist.

**Response:**
```
Error: Combined report file not found: {file_path}

Please ensure the debate-based-planning skill completed successfully
and the combined report was generated.

Expected file format: .tmp/debate-report-YYYYMMDD-HHMMSS.md
```

Stop execution.

### External Reviewer Tools Unavailable

Neither Codex nor Claude CLI is installed.

**Response:**
```
Error: External review tools unavailable.

The external-review.sh script requires one of:
- Codex CLI: https://github.com/openai/codex
- Claude CLI: https://github.com/anthropics/claude-cli

Please install one of these tools and try again.

Alternatively, you can manually review the combined debate report:
{combined_report_file}
```

Offer manual review option.

### External Reviewer Failure

Script exits with non-zero code (API error, timeout, etc.).

**Response:**
```
Error: External review failed.

Script exit code: {code}
Error output: {stderr}

Possible causes:
- API rate limit reached
- Network connection issue
- Invalid API credentials
- Malformed input

Retry external consensus review? (y/n)
```

Offer retry or manual fallback.

### Invalid Consensus Plan Output

External reviewer returns output but it's missing required sections.

**Response:**
```
Warning: Consensus plan may be incomplete.

Missing required sections:
{missing_sections}

The external reviewer output is available but may need manual review.

Output saved to: {output_file}

Options:
1. Review plan manually and proceed
2. Retry external consensus with different prompt
3. Skip external review and manually create plan
```

Wait for user decision.

### Empty Output

External reviewer returns empty response.

**Response:**
```
Error: External reviewer returned empty output.

This could indicate:
- API timeout
- Input too large for model context
- Malformed prompt template

Debug steps:
1. Check combined report size: wc -l {combined_report_file}
2. Check prompt template: .tmp/templates/external-review-prompt.md
3. Try running script manually:
   ./scripts/external-review.sh {combined_report_file} "{feature_name}" "{feature_description}"
```

Provide debugging guidance.

## Usage Examples

### Example 1: Successful Consensus

**Input:**
```
Combined report: .tmp/debate-report-20251225-155030.md
Feature name: "JWT Authentication"
Feature description: "Add user authentication with JWT tokens"
```

**Output:**
```
External consensus review complete!

Consensus Plan Summary:
- Feature: JWT Authentication
- Total LOC: ~280 (Medium)
- Components: 4
- Critical risks: 1

Key Decisions:
- From Bold Proposal: Accepted JWT with refresh tokens
- From Critique: Addressed token storage security concern
- From Reducer: Removed OAuth2 complexity, kept simple JWT

Consensus plan saved to: .tmp/consensus-plan-20251225-160245.md

Next step: Review plan and create GitHub issue with open-issue skill.
```

### Example 2: Codex Unavailable, Claude Fallback

**Output:**
```
Using Claude Opus as fallback for external consensus...

[Claude Opus generates consensus plan]

External consensus review complete!
[Summary as above...]

Note: Used Claude Opus (Codex unavailable)
```

### Example 3: Manual Fallback

**Scenario:** Both Codex and Claude CLI unavailable.

**Output:**
```
Error: External review tools unavailable.

The external-review.sh script requires Codex or Claude CLI.

Manual review option:
1. Review combined debate report: .tmp/debate-report-20251225-155030.md
2. Synthesize consensus plan manually
3. Save plan to: .tmp/consensus-plan-{timestamp}.md
4. Continue with open-issue skill

Proceed with manual review? (y/n)
```

## Integration Points

This skill is designed to be invoked by:
- **ultra-planner command**: After debate-based-planning skill completes

This skill outputs to:
- **open-issue skill**: Consensus plan becomes GitHub issue body
- **User approval**: Plan presented for user review before issue creation

## Notes

- External reviewer is **required** for consensus (not optional)
- Codex is **preferred** due to cost and speed
- Claude Opus is **fallback** with same capability
- Manual review is **last resort** if tools unavailable
- Prompt template is **customizable** in `.tmp/templates/external-review-prompt.md`
- Consensus plan format follows **standard implementation plan structure**
- Execution time: 1-3 minutes (depending on model and API latency)
- Cost: Single Opus API call (~$0.50-2.00 depending on report size)
