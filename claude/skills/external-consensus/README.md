# External Consensus Skill

## Purpose

Synthesize a balanced, consensus implementation plan from multi-agent debate reports using external AI review (Codex or Claude Opus).

This skill acts as the "tie-breaker" and "integrator" in the ultra-planner workflow, resolving conflicts between three agent perspectives and combining their insights into a coherent implementation plan.

## Files

- **SKILL.md** - Main skill implementation with detailed workflow
- **external-review-prompt.md** - AI prompt template for external consensus review

## Integration

### Used By
- `ultra-planner` command - Invoked after debate-based-planning skill completes

### Outputs To
- `open-issue` skill - Consensus plan becomes GitHub issue body
- User approval - Plan presented for review before issue creation

## Dependencies

### Required
- **scripts/external-review.sh** - Shell script that invokes external CLI tools
- **Combined debate report** - Output from debate-based-planning skill (3 agents)

### External Tools (one required)

#### Codex CLI (Preferred)

The skill uses advanced Codex CLI features for optimal consensus review:

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

#### Claude Code CLI (Fallback)

When Codex is unavailable, falls back to Claude Code with Opus:

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
- Seamless fallback when Codex unavailable
- Cost: ~$1.00-3.00 per review
- Time: 1-3 minutes

### Templates
- **external-review-prompt.md** - Prompt template with placeholders:
  - `{{FEATURE_NAME}}` - Short feature name
  - `{{FEATURE_DESCRIPTION}}` - Brief description
  - `{{COMBINED_REPORT}}` - Full 3-agent debate report

## How It Works

1. Loads combined debate report from `.tmp/debate-report-*.md`
2. Fills prompt template with feature context and debate content
3. Invokes external AI (Codex or Claude Opus) to synthesize consensus
4. Validates output has required implementation plan sections
5. Saves consensus plan to `.tmp/consensus-plan-*.md`
6. Returns summary with LOC estimate and key decisions

## Notes

- External reviewer provides **neutral, unbiased** perspective
- Codex preferred for **advanced features**: web search, xhigh reasoning, read-only sandbox
- Claude Opus fallback with **same research capability**: WebSearch, WebFetch, read-only tools
- **File-based I/O pattern**: Uses `.tmp/` directory with timestamps to avoid conflicts
- **Execution time**: 2-5 minutes (Codex with xhigh reasoning), 1-3 minutes (Claude)
- **Cost considerations**: Higher with advanced features but justified by quality
  - Codex: ~$0.50-1.50 per review
  - Claude: ~$1.00-3.00 per review
- **Security**: Both use read-only restrictions (sandbox/tools)
- **Quality benefits**: Web search enables fact-checking, xhigh reasoning produces thorough analysis
- **Fallback guarantee**: Claude Code is always available as part of this skill
