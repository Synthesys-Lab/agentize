---
name: external-consensus
description: Synthesize consensus implementation plan from multi-agent debate reports using external AI review
allowed-tools:
  - Bash(date:*)
  - Bash(cat:*)
  - Bash(sed:*)
  - Bash(mktemp:*)
  - Bash(test:*)
  - Bash(wc:*)
  - Bash(command:*)
  - Bash(codex:*)
  - Bash(claude:*)
---

# External Consensus Skill

This skill invokes an external AI reviewer (Codex or Claude Opus) to synthesize a balanced, consensus implementation plan from the combined multi-agent debate report.

## CLI Tool Usage

This skill uses external CLI tools for consensus review. The implementation pattern follows best practices for security, reasoning quality, and external research capabilities.

### Codex CLI (Preferred)

The skill uses `codex exec` with advanced features:

```bash
# Create temporary files for input/output
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
INPUT_FILE=".tmp/external-review-input-$TIMESTAMP.md"
OUTPUT_FILE=".tmp/external-review-output-$TIMESTAMP.txt"

# Write prompt to input file
echo "$FULL_PROMPT" > "$INPUT_FILE"

# Invoke Codex with advanced features (prompt read from stdin via -)
codex exec \
    -m gpt-5.2-codex \
    -s read-only \
    --enable web_search_request \
    -c model_reasoning_effort=xhigh \
    -o "$OUTPUT_FILE" \
    - < "$INPUT_FILE"

# Read output
CONSENSUS_PLAN=$(cat "$OUTPUT_FILE")
```

**Configuration details:**
- **Model**: `gpt-5.2-codex` - Latest Codex model with enhanced reasoning
- **Sandbox**: `read-only` - Security restriction (no file writes)
- **Web Search**: `--enable web_search_request` - External research capability for fact-checking and SOTA patterns
- **Reasoning Effort**: `model_reasoning_effort=xhigh` - Maximum reasoning depth for thorough analysis

**Benefits:**
- Web search allows fact-checking technical decisions and researching best practices
- High reasoning effort produces more thorough trade-off analysis
- Read-only sandbox ensures security
- File-based I/O handles large debate reports reliably

### Claude Code CLI (Fallback)

When Codex is unavailable, the skill falls back to Claude Code with Opus:

```bash
# Create temporary files
INPUT_FILE=".tmp/external-review-input-$TIMESTAMP.md"
OUTPUT_FILE=".tmp/external-review-output-$TIMESTAMP.txt"

# Write prompt to input file
echo "$FULL_PROMPT" > "$INPUT_FILE"

# Invoke Claude Code with Opus model and read-only tools
claude -p \
    --model opus \
    --tools "Read,Grep,Glob,WebSearch,WebFetch" \
    --permission-mode bypassPermissions \
    < "$INPUT_FILE" > "$OUTPUT_FILE"

# Read output
CONSENSUS_PLAN=$(cat "$OUTPUT_FILE")
```

**Configuration details:**
- **Model**: `opus` - Claude Opus 4.5 with highest reasoning capability
- **Tools**: Limited to read-only tools (Read, Grep, Glob, WebSearch, WebFetch)
- **Permission Mode**: `bypassPermissions` - Skip permission prompts for automated execution
- **File I/O**: Input via stdin, output via stdout redirection

**Benefits:**
- Same research capabilities (WebSearch, WebFetch) as Codex
- High reasoning quality from Opus model
- Read-only tools ensure security
- Seamless fallback when Codex unavailable

### Cost and Timing Considerations

**Codex (gpt-5.2-codex with xhigh reasoning):**
- Cost: ~$0.50-1.50 per consensus review (varies with debate report size)
- Time: 2-5 minutes (xhigh reasoning takes longer but produces better results)

**Claude Opus (fallback):**
- Cost: ~$1.00-3.00 per consensus review
- Time: 1-3 minutes

The increased cost and time from high reasoning effort and web search are justified by:
- More thorough analysis of trade-offs between agent perspectives
- Fact-checked technical decisions
- Research-backed implementation recommendations
- Higher quality consensus plans

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

### Step 2: Prepare Prompt and Invoke External Reviewer

Prepare the consensus review prompt:

1. Load prompt template from `.claude/skills/external-consensus/external-review-prompt.md`
2. Substitute variables using sed:
   ```bash
   PROMPT_TEMPLATE=$(cat ".claude/skills/external-consensus/external-review-prompt.md")
   COMBINED_REPORT=$(cat "$COMBINED_REPORT_FILE")

   # Substitute FEATURE_NAME and FEATURE_DESCRIPTION
   echo "$PROMPT_TEMPLATE" | \
       sed "s|{{FEATURE_NAME}}|$FEATURE_NAME|g" | \
       sed "s|{{FEATURE_DESCRIPTION}}|$FEATURE_DESCRIPTION|g" > "$INPUT_FILE.tmp"

   # Replace {{COMBINED_REPORT}} with actual report content
   TEMP_REPORT=$(mktemp)
   echo "$COMBINED_REPORT" > "$TEMP_REPORT"
   sed -e '/{{COMBINED_REPORT}}/r '"$TEMP_REPORT" -e '/{{COMBINED_REPORT}}/d' "$INPUT_FILE.tmp" > "$INPUT_FILE"
   rm "$TEMP_REPORT" "$INPUT_FILE.tmp"
   ```
3. Verify prompt was created: `test -f "$INPUT_FILE" && wc -l "$INPUT_FILE"`

Invoke external reviewer (try Codex first, fallback to Claude Code):

**Check if Codex is available:**
```bash
command -v codex &> /dev/null
```

**If Codex is available:**
```bash
# IMPORTANT: Use '-' to read prompt from stdin, not '-i' (which is for images)
codex exec \
    -m gpt-5.2-codex \
    -s read-only \
    --enable web_search_request \
    -c model_reasoning_effort=xhigh \
    -o ".tmp/external-review-output-{timestamp}.txt" \
    - < ".tmp/external-review-input-{timestamp}.md"
```

**If Codex is unavailable, use Claude Code:**
```bash
claude -p \
    --model opus \
    --tools "Read,Grep,Glob,WebSearch,WebFetch" \
    --permission-mode bypassPermissions \
    < ".tmp/external-review-input-{timestamp}.md" \
    > ".tmp/external-review-output-{timestamp}.txt"
```

**Execution notes:**
- Codex with xhigh reasoning takes 2-5 minutes to complete
- Claude Opus typically takes 1-3 minutes
- Can run in background if desired (use bash run_in_background parameter)
- Check output file exists with `test -f` and verify non-empty with `wc -l`

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

Read the consensus plan from output file:

```bash
CONSENSUS_PLAN=$(cat ".tmp/external-review-output-{timestamp}.txt")
```

**Error handling:**
- If output file doesn't exist or is empty, external review failed
- Check stderr for error messages
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

### Codex CLI Unavailable (Auto-fallback to Claude)

When Codex CLI is not installed, the script automatically falls back to Claude Code (which is always available as part of this skill).

**Response:**
```
Codex not available. Using Claude Opus as fallback...

[Claude Code executes consensus review with same capabilities]
```

The fallback is seamless and maintains the same research capabilities (WebSearch, WebFetch) and read-only security restrictions.

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
- Web search request timeout (Codex only)
- Reasoning effort timeout (xhigh setting)

Retry external consensus review? (y/n)
```

Offer retry or manual fallback.

### Temporary File Conflicts

Multiple concurrent runs create conflicting temp files.

**Response:**
```
Warning: Temporary file already exists: {temp_file}

This may indicate a concurrent run of the external-review.sh script.

Options:
1. Wait for previous run to complete
2. Clean up stale temp files: rm .tmp/external-review-*
3. Continue (may overwrite previous run)
```

Timestamp-based file naming prevents most conflicts, but this handles edge cases.

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
2. Check prompt template exists: .claude/skills/external-consensus/external-review-prompt.md
3. Try invoking Codex or Claude Code manually with a simple test prompt
```

Provide debugging guidance.

## Usage Examples

### Example 1: Successful Consensus with Codex

**Input:**
```
Combined report: .tmp/debate-report-20251225-155030.md
Feature name: "JWT Authentication"
Feature description: "Add user authentication with JWT tokens"
```

**Execution:**
```
Using Codex (gpt-5.2-codex) for external consensus review...

[Codex executes with advanced features:]
- Model: gpt-5.2-codex
- Sandbox: read-only
- Web search: enabled (researching JWT best practices)
- Reasoning effort: xhigh
- Input: .tmp/external-review-input-20251225-160130.md
- Output: .tmp/external-review-output-20251225-160130.txt
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
- From Critique: Addressed token storage security concern (httpOnly cookies)
- From Reducer: Removed OAuth2 complexity, kept simple JWT

Research Applied:
- Verified OWASP JWT security guidelines (via web search)
- Confirmed refresh token rotation best practices
- Fact-checked token expiration standards

Consensus plan saved to: .tmp/consensus-plan-20251225-160245.md

Next step: Review plan and create GitHub issue with open-issue skill.
```

### Example 2: Web Search Usage

**Scenario:** Feature requires external research for SOTA patterns.

**Input:**
```
Feature name: "Real-time Collaboration"
Feature description: "Add multi-user real-time editing with CRDT"
```

**Codex behavior:**
```
Using Codex (gpt-5.2-codex) for external consensus review...

[Web search queries executed:]
- "CRDT implementation best practices 2025"
- "Yjs vs Automerge performance comparison"
- "Operational transformation vs CRDT trade-offs"

[External research findings incorporated into consensus:]
- Yjs recommended for browser-based collaboration (proven, actively maintained)
- WebSocket vs WebRTC trade-off analysis
- Conflict resolution strategies from recent papers
```

**Output includes fact-checked decisions based on web research.**

### Example 3: Claude Fallback with Research

**Scenario:** Codex unavailable, Claude Code (always available) provides same research capabilities.

**Output:**
```
Codex not available. Using Claude Opus as fallback...

[Claude Opus executes with:]
- Model: opus
- Tools: Read, Grep, Glob, WebSearch, WebFetch (read-only)
- Permission mode: bypassPermissions
- Input: .tmp/external-review-input-20251225-160130.md (via stdin)
- Output: .tmp/external-review-output-20251225-160130.txt (via stdout)

External consensus review complete!
[Summary as Example 1...]

Note: Used Claude Opus (Codex unavailable)
Research capability: WebSearch and WebFetch used for fact-checking
```

## Integration Points

This skill is designed to be invoked by:
- **ultra-planner command**: After debate-based-planning skill completes

This skill outputs to:
- **open-issue skill**: Consensus plan becomes GitHub issue body
- **User approval**: Plan presented for user review before issue creation

## Notes

- External reviewer is **required** for consensus (not optional)
- Codex with `gpt-5.2-codex` is **preferred** for advanced features (web search, xhigh reasoning)
- Claude Opus is **fallback** with same research capabilities
- Manual review is **last resort** if tools unavailable
- Prompt template is **customizable** in `./external-review-prompt.md` (in skill folder)
- Consensus plan format follows **standard implementation plan structure**
- **File-based I/O** pattern: Uses `.tmp/` directory with timestamps for input/output
- **Execution time**: 2-5 minutes with Codex (xhigh reasoning), 1-3 minutes with Claude
- **Cost**: Higher with advanced features but justified by quality:
  - Codex gpt-5.2-codex: ~$0.50-1.50 per review
  - Claude Opus: ~$1.00-3.00 per review
- **Security**: Read-only sandbox/tools ensure no file modifications
- **Research capability**: Web search enables fact-checking and SOTA pattern research
- **Reasoning quality**: xhigh effort produces more thorough trade-off analysis
