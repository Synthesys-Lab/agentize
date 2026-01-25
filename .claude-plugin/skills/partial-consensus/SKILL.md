---
name: partial-consensus
description: Determine consensus/disagreement from 5-agent debate - exposes disagreements as developer decisions
allowed-tools:
  - Bash(.claude-plugin/skills/partial-consensus/scripts/partial-consensus.sh:*)
  - Bash(cat:*)
  - Bash(test:*)
  - Bash(wc:*)
  - Bash(grep:*)
---

# Partial Consensus Skill

This skill determines consensus and exposes disagreements from a multi-agent debate with dual proposers.

## Modes

1. **Standard mode**: Determines consensus/disagreement, generates options for disagreements
2. **Resolve mode**: Same 5 reports but with "User Resolution" section appended, produces unified plan

## Key Features

- **No Automatic Dropping**: AI cannot drop ideas from proposals; all contested ideas become Disagreement sections
- **Mandatory Developer Arbitration**: Disagreements require explicit developer selection via `--resolve` mode
- **Flexible Options**: Minimum 2, recommended 3, no upper limit per disagreement
- **Source Attribution**: Each option must cite its source (Bold, Paranoia, Hybrid, etc.)
- **AI Recommendations**: Advisory only; developer must select
- **Collapsible Code Drafts**: `<details>` tags for implementation details

## Inputs

This skill requires 5 agent report file paths, with optional 6th and 7th arguments:
- **Report 1**: Bold proposer report (`.tmp/issue-{N}-bold.md`)
- **Report 2**: Paranoia proposer report (`.tmp/issue-{N}-paranoia.md`)
- **Report 3**: Critique report (`.tmp/issue-{N}-critique.md`)
- **Report 4**: Proposal reducer report (`.tmp/issue-{N}-proposal-reducer.md`)
- **Report 5**: Code reducer report (`.tmp/issue-{N}-code-reducer.md`)
- **Arg 6** (optional): Previous consensus file (`.tmp/issue-{N}-consensus.md`)
- **Arg 7** (optional): History file (`.tmp/issue-{N}-history.md`)

**Context ordering rationale:**
The combined report is assembled as: agent reports (1-5) -> previous consensus (6) -> history (7).
This ensures the AI sees the history table's last row (current task) as the final context,
leveraging LLM recency bias to prioritize the current request.

**For resolve/refine modes:** Pass both 6th and 7th arguments:
1. consensus.md as arg 6 (previous plan being modified)
2. history.md as arg 7 (operation history with current task in last row)

## Outputs

**Files created:**
- `.tmp/issue-{N}-debate.md` - Combined 5-agent debate report (7 parts if resolve mode)
- `.tmp/issue-{N}-consensus.md` - Final plan(s)
- `.tmp/issue-{N}-history.md` - Accumulated selection and refine history

**For resolve/refine mode, the debate file includes additional sections:**
- Part 6: Previous Consensus Plan (from consensus.md)
- Part 7: Selection & Refine History (from history file, last row = current task)

**Output format:**

| Section | Description |
|---------|-------------|
| Agent Perspectives Summary | 5-agent position table |
| Consensus Status | 3-condition evaluation with CONSENSUS/DISAGREEMENT verdict |
| Goal / Codebase Analysis | Problem statement and file changes |
| Implementation Steps | Agreed changes with code drafts |
| Disagreement N (if any) | Per-disagreement options with A/B/C choices |
| Disagreement Summary | Summary table and suggested combination |
| Validation (resolve mode) | Selection history and compatibility check |

*See `partial-review-prompt.md` for complete output format specification.*

## Implementation Workflow

### Step 1: Invoke Partial Consensus Script

```bash
.claude-plugin/skills/partial-consensus/scripts/partial-consensus.sh \
    .tmp/issue-42-bold.md \
    .tmp/issue-42-paranoia.md \
    .tmp/issue-42-critique.md \
    .tmp/issue-42-proposal-reducer.md \
    .tmp/issue-42-code-reducer.md
```

**Script automatically:**
1. Validates all 5 report files exist
2. Extracts issue number from first report filename
3. Combines all 5 reports into debate report
4. Invokes external AI (Codex or Claude Opus)
5. Determines if consensus or multiple options
6. Saves result to consensus file

**Timeout**: 30 minutes (same as external-consensus)

## Error Handling

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `Report file not found: {path}` | Missing agent report | Ensure all 5 reports were generated |
| `External review failed with exit code {N}` | API/network issue | Check credentials and retry |

## Usage Examples

| Mode | Arguments | Example |
|------|-----------|---------|
| Standard | 5 reports | `.tmp/issue-{N}-bold.md ... .tmp/issue-{N}-code-reducer.md` |
| Resolve | 5 reports + consensus + history | Add `.tmp/issue-{N}-consensus.md .tmp/issue-{N}-history.md` |
| Refine | Same as resolve | Same `issue-{N}` prefix, history records refine operation |

```bash
# Standard mode
.claude-plugin/skills/partial-consensus/scripts/partial-consensus.sh \
    .tmp/issue-42-bold.md \
    .tmp/issue-42-paranoia.md \
    .tmp/issue-42-critique.md \
    .tmp/issue-42-proposal-reducer.md \
    .tmp/issue-42-code-reducer.md
```

**Output** (stdout, last line):
```
.tmp/issue-42-consensus.md
```
