---
name: external-consensus
description: Synthesize consensus implementation plan from multi-agent debate reports using external AI review
allowed-tools:
  - Bash(.claude/skills/external-consensus/scripts/external-consensus.sh:*)
  - Bash(cat:*)
  - Bash(test:*)
  - Bash(wc:*)
  - Bash(grep:*)
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

**Design Principle**: Minimize human intervention by avoiding environment variable management. The script should be invoked directly and handle all operations autonomously, outputting results to stdout for the user to review.

### Step 1: Invoke External Consensus Script

Direct invocation - the script handles everything and outputs summary:

```bash
# Simple invocation: script auto-extracts feature info and outputs summary
.claude/skills/external-consensus/scripts/external-consensus.sh .tmp/debate-report-20251226-132218.md

# With explicit feature name and description (optional)
.claude/skills/external-consensus/scripts/external-consensus.sh \
    .tmp/debate-report-20251226-132218.md \
    "Review-Standard Simplification" \
    "Simplify skill while adding scoring"
```

**Script automatically:**
1. Validates debate report exists
2. Extracts feature name/description from report if not provided
3. Loads and processes prompt template with variable substitution
4. Checks if Codex is available (prefers Codex with xhigh reasoning)
5. Falls back to Claude Opus if Codex unavailable
6. Invokes external AI with appropriate configuration:
   - **Codex**: `gpt-5.2-codex`, read-only sandbox, web search enabled, xhigh reasoning (2-5 min)
   - **Claude**: Opus model, read-only tools, bypassPermissions (1-3 min)
7. Saves consensus plan to `.tmp/consensus-plan-{timestamp}.md`
8. Validates output and extracts summary information
9. Outputs consensus file path on stdout (last line)
10. Displays summary information on stderr for user review

**Required inputs:**
- Path to combined debate report (required)
- Feature name (optional, auto-extracted from report)
- Feature description (optional, auto-extracted from report)

**No environment variables needed** - just invoke the script and review the output

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

**Script output on stdout (last line):**
```
.tmp/consensus-plan-20251226-150643.md
```

**Script output on stderr (summary for review):**
```
Using external AI reviewer for consensus synthesis...

Configuration:
- Input: .tmp/external-review-input-20251226-150643.md (1012 lines)
- Output: .tmp/external-review-output-20251226-150643.txt
- Model: gpt-5.2-codex (Codex CLI)
- Sandbox: read-only
- Web search: enabled
- Reasoning effort: xhigh

This will take 2-5 minutes with xhigh reasoning effort...

[Codex execution details...]

External consensus review complete!

Consensus Plan Summary:
- Feature: Review-Standard Simplification with Scoring
- Total LOC: ~350-420 (Medium)
- Implementation Steps: 3
- Risks Identified: 4

Key Decisions:
- Accepted from Bold Proposal: Keep explicit evidence requirements
- Addressed from Critique: Preserve Phase 3 specialized checks
- Applied from Reducer: Single-file architecture, compress prose

Consensus plan saved to: .tmp/consensus-plan-20251226-150643.md
```

The script performs validation and summary extraction internally - no additional steps needed.

## Error Handling

The `external-consensus.sh` script handles most error scenarios internally. Here are the main error cases:

### Combined Report Not Found

The script validates that the debate report file exists. If not, it exits with:

```
Error: Debate report file not found: {file_path}
```

**Solution**: Ensure the debate-based-planning skill completed successfully and generated the report.

### Codex CLI Unavailable (Auto-fallback to Claude)

The script automatically detects if Codex is available and falls back to Claude Opus:

```
Codex not available. Using Claude Opus as fallback...
```

This is seamless and maintains the same research capabilities (WebSearch, WebFetch) and read-only security.

### External Reviewer Failure

If the external AI (Codex or Claude) fails, the script exits with a non-zero code:

```
Error: External review failed with exit code {code}
```

**Possible causes:**
- API rate limit reached
- Network connection issue
- Invalid API credentials
- Web search timeout (Codex only)
- Reasoning effort timeout (xhigh setting)

**Solution**: Check API credentials, network connection, or retry with different settings.

### Invalid or Incomplete Output

If the consensus plan is missing required sections, Step 2 validation will detect it:

```
Warning: Consensus plan may be incomplete. Missing sections: {list}
The plan is available at: {file_path}
```

**Solution**: Review the plan manually, adjust the prompt template if needed, or retry the external consensus review.

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
