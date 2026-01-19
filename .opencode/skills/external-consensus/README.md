# External Consensus Skill

## Purpose

Synthesize a balanced, consensus implementation plan from multi-agent debate reports using external AI review (Codex, Cursor Agent CLI, or Claude Opus).

This skill acts as the "tie-breaker" and "integrator" in the ultra-planner workflow, resolving conflicts between three agent perspectives and combining their insights into a coherent implementation plan.

## Files

- **SKILL.md** - Main skill implementation with detailed workflow
- **external-review-prompt.md** - AI prompt template for external consensus review
- **scripts/external-consensus.sh** - Formalized script encapsulating all execution logic

## Integration

### Used By
- `ultra-planner` command - Invoked after debate-based-planning skill completes

### Outputs To
- `open-issue` skill - Consensus plan becomes GitHub issue body
- User approval - Plan presented for review before issue creation

## Dependencies

### Required
- **Combined debate report** - Output from debate-based-planning skill (3 agents)
- **Prompt template** - external-review-prompt.md (in skill directory)

### External Tools (three-tier fallback)

The skill uses a three-tier fallback strategy to leverage the best available advanced reasoning tool:

#### Tier 1: Codex CLI (Preferred)

The skill prefers advanced Codex CLI features for optimal consensus review:

**Installation**: Codex CLI (varies by distribution)

**Usage pattern**:
```bash
codex exec \
    -m gpt-5.2-codex \              # Latest Codex model
    -s read-only \                  # Security: read-only sandbox
    --enable web_search_request \   # Enable external research
    -c model_reasoning_effort=xhigh # Maximum reasoning depth
    -i input.md \                   # Input file
    -o output.txt                   # Output file
```

**Features used**:
- **gpt-5.2-codex model**: Latest version with enhanced reasoning
- **Read-only sandbox**: Security restriction preventing file writes
- **Web search**: Fact-checking and SOTA pattern research
- **xhigh reasoning effort**: Thorough trade-off analysis
- **File-based I/O**: Reliable handling of large debate reports

**Benefits**:
- More thorough analysis from web-enabled research
- Fact-checked technical decisions
- Higher quality consensus plans
- Cost: ~$0.50-1.50 per review
- Time: 2-5 minutes (xhigh reasoning)

#### Tier 2: Cursor Agent CLI (Intermediate Fallback)

When Codex is unavailable but Cursor Agent CLI is available with GPT-5.2-Codex-xhigh, use it as intermediate fallback:

**Installation**: Cursor Agent CLI (`agent` command in PATH)

**Detection**:
```bash
command -v agent &> /dev/null       # Check CLI availability
```

**Usage pattern**:
```bash
cat input.md | agent -p > output.txt  # Pipe input through agent -p flag
```

**Features used**:
- **gpt-5.2-codex-xhigh model**: Advanced reasoning capabilities
- **External research**: Via Agent CLI routing
- **File I/O**: Stdin/stdout redirection

**Benefits**:
- Access to advanced reasoning models when Codex unavailable
- Research capabilities similar to Claude
- Cost: Varies by Cursor Agent CLI configuration
- Time: Similar to Claude (1-3 minutes)

#### Tier 3: Claude Code CLI (Final Fallback)

When both Codex and Cursor Agent CLI are unavailable, falls back to Claude Code with Opus:

**Installation**: Claude Code CLI (https://github.com/anthropics/claude-code)

**Usage pattern**:
```bash
claude -p \
    --model opus \                                      # Claude Opus 4.5
    --tools "Read,Grep,Glob,WebSearch,WebFetch" \      # Read-only tools
    --permission-mode bypassPermissions \               # Automated execution
    < input.md > output.txt                            # File I/O via redirection
```

**Features used**:
- **Opus model**: Highest reasoning capability
- **Read-only tools**: Security restriction (no Edit/Write)
- **WebSearch & WebFetch**: External research capability
- **Bypass permissions**: No prompts during automated execution
- **File I/O**: Stdin/stdout redirection

**Benefits**:
- Same research capabilities as Codex
- High reasoning quality from Opus
- Always available as fallback guarantee
- Cost: ~$1.00-3.00 per review
- Time: 1-3 minutes

### Templates
- **external-review-prompt.md** - Prompt template with placeholders:
  - `{{FEATURE_NAME}}` - Short feature name
  - `{{FEATURE_DESCRIPTION}}` - Brief description
  - `{{COMBINED_REPORT}}` - Full 3-agent debate report

## How It Works

The skill uses a formalized script (`scripts/external-consensus.sh`) that:

1. Parses input to detect issue number or path mode
2. Resolves debate report path (`.tmp/issue-{N}-debate.md` if issue number provided)
3. Validates the debate report file exists
4. Extracts feature name from reports using robust pattern matching:
   - Accepts headers (`# Feature:`), bold labels (`**Feature**:`), or plain labels (`Feature:`)
   - Case-insensitive matching for `Feature`, `Title`, or `Feature Request`
   - Scans reports 1 → 2 → 3 in priority order until first match found
   - Falls back to "Unknown Feature" only when no label exists in any report
5. Loads and processes the prompt template with variable substitution
6. Applies three-tier fallback strategy:
   - **Tier 1**: Check if Codex available → use Codex with xhigh reasoning
   - **Tier 2**: Check if Agent CLI available with gpt-5.2-codex-xhigh → use Agent CLI
   - **Tier 3**: Fall back to Claude Opus with read-only tools
7. Invokes external AI with appropriate configuration:
   - **Codex**: gpt-5.2-codex, read-only sandbox, web search, xhigh reasoning
   - **Agent CLI**: gpt-5.2-codex-xhigh via Cursor Agent CLI
   - **Claude**: Opus model, read-only tools (Read, Grep, Glob, WebSearch, WebFetch)
8. Saves consensus plan to `.tmp/issue-{N}-consensus.md` (issue mode) or `.tmp/consensus-plan-{timestamp}.md` (path mode)
9. Returns the consensus file path for validation and summary extraction

## Notes

- External reviewer provides **neutral, unbiased** perspective
- **Three-tier fallback cascade**: Codex → Agent CLI → Claude Opus
  - Maximizes access to advanced reasoning models when available
  - Preserves existing behavior while adding intermediate option
  - Always has working fallback (Claude Opus)
- **File-based I/O pattern**: Uses `.tmp/` directory with timestamps to avoid conflicts
- **Execution time**: 2-5 minutes (Codex with xhigh reasoning), 1-3 minutes (Agent CLI/Claude)
- **Cost considerations**: Varies by tier
  - Codex: ~$0.50-1.50 per review (highest cost, advanced features)
  - Agent CLI: Varies by Cursor Agent CLI config (intermediate)
  - Claude: ~$1.00-3.00 per review (higher cost, always available)
- **Security**: All tiers use read-only restrictions (sandbox/tools)
- **Quality benefits**: Tier 1-2 enable fact-checking and thorough analysis
- **Fallback guarantee**: Claude Code is always available as final fallback
