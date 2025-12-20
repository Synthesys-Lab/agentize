# LLM Agent Milestone Framework

## Purpose

This rule provides a standardized framework for creating milestone summaries when a development session ends with incomplete work. The goal is to enable the next LLM agent to quickly understand context and continue work efficiently.

---

## Milestone Output Format

Milestones are created as GitHub issues. This provides:
- Tracking in GitHub project board
- Linking to parent issues and PRs
- Searchable and filterable
- Support for labels and categorization
- Comments for updates and discussion

**Created by**:
- `/gen-milestone` command
- `milestone-generator` agent (automated via `/issue2impl`)

---

## When to Create a Milestone Summary

Create a milestone summary when:
- Development session involves multi-step tasks spanning multiple hours
- Some tasks are completed but others remain pending
- Context and decisions made during the session are valuable for continuation
- User explicitly requests a summary for the next agent
- **PR size exceeds threshold** (>1000 lines, triggered automatically by `/issue2impl`)

Do NOT create milestone summaries for:
- Simple, single-step tasks already completed
- Exploratory conversations without actionable tasks
- Sessions where all work is fully finished

---

## Integration with /issue2impl

The `/issue2impl` command includes automatic milestone generation:

### Size Thresholds

| Lines Changed | Action |
|---------------|--------|
| < 800 | Continue normally |
| 800-1000 | Monitor, find breakpoint if needed |
| 1000-1200 | Consider milestone |
| > 1200 | **Must create milestone** |

### Automatic Flow

1. `/issue2impl` monitors PR size during implementation
2. When threshold exceeded, spawns `milestone-generator` agent
3. Agent creates GitHub issue with milestone structure
4. Issue linked to parent, PR marked as partial
5. Next session uses milestone issue to continue

---

## Milestone Summary Structure

### Section 1: Current Status Snapshot

**What to include**:
- Quantifiable metrics showing progress (e.g., test pass rates, files modified, lines added)
- List of completed deliverables with commit IDs or references
- Current working state (build passing, tests status, any blockers)
- **MANDATORY**: Clear statement of the primary goal/objective

**What to exclude**:
- Detailed explanations of what was done (user has conversation history)
- Step-by-step implementation details
- Code snippets of completed work

**Format**:
```
Current Status:
- Metric 1: X/Y (Z%)
- Metric 2: Value
- Latest commits: [hash] description

Primary Goal: [Clear statement of what needs to be accomplished]
- Example: "Implement constant handling for atomic operations to pass test_atomic_add_const"
- Example: "Fix 5 failing tests in convert-memory-atomic.mlir"
- Example: "Add support for scatter-add patterns to enable e2e-spmv.mlir test"

Completed deliverables:
1. Item A
2. Item B
```

---

### Section 2: Critical Rules and Protocols

**What to include**:
- Project-specific policies that could cause issues if violated
- Testing/modification restrictions
- Approval requirements
- Code standards specific to this project

**What to exclude**:
- General programming best practices
- Standard git workflows
- Common sense guidelines

**Format**:
```
Critical Rule: [Name]
- Requirement: Specific rule description
- Violation consequence: What happens if broken
- Examples: Good and bad cases
```

---

### Section 3: Technical Knowledge Gained

**What to include**:
- Non-obvious insights discovered during implementation
- Gotchas and edge cases encountered
- Design decisions and their rationale
- Key architectural patterns or constraints

**What to exclude**:
- Common knowledge or standard practices
- Information easily found in documentation
- Obvious implementation details

**Format**:
```
Key Insight: [Topic]
- Discovery: What was learned
- Implication: How it affects implementation
- Example: Concrete illustration
```

---

### Section 4: Unfinished Tasks (Priority Ordered)

**What to include**:
- Clear, actionable task descriptions
- Priority ordering with difficulty estimates
- Prerequisites or dependencies
- Expected impact (what will be unlocked)
- Specific file locations or entry points
- **MANDATORY**: List of all expected failed tests and their reasons

**What to exclude**:
- Vague or unclear objectives
- Tasks without clear definition
- Internal implementation steps (agent will figure out)
- Already completed work

**Format**:
```
Priority N: [Task Name] (X hours, DIFFICULTY level)

Objective: What needs to be accomplished
Pattern/Requirement: What to recognize or implement
Target: Which files or tests are affected
Expected gain: Measurable outcome (specific test names that will pass)
Implementation hints: Where to start (file, line, function)

Expected Failed Tests:
- test_name.mlir: Reason for failure
- test_name.cpp: Reason for failure
```

**Difficulty levels**: LOW, MEDIUM, HIGH, COMPLEX

---

### Section 5: Code Navigation Guide

**What to include**:
- Key file paths with line number ranges for important sections
- Entry points for adding new functionality
- Helper functions or utilities available
- Where to find similar existing implementations

**What to exclude**:
- Complete file listings
- Detailed code walkthroughs
- Implementation logic

**Format**:
```
Main implementation: /path/to/file (total lines)
- Line X-Y: Feature A
- Line Z-W: Feature B

Helper functions:
- functionName() - Line N: Purpose
```

---

### Section 6: Recommended Next Steps

**What to include**:
- 2-3 concrete action options with time estimates
- Trade-offs between options (quick wins vs high impact)
- Clear recommendation if applicable
- First commands to run to get started

**What to exclude**:
- More than 3 options (causes decision paralysis)
- Vague suggestions
- Overly detailed implementation plans

**Format**:
```
Option A: [Name] (X hours) [Tag if recommended]
- Approach: High-level strategy
- Impact: What it achieves
- Why: Rationale for this option

Option B: [Name] (Y hours)
...
```

---

### Section 7: Direct Milestone Command

**What to include**:
- A single, clear, self-contained instruction that the next agent can immediately execute
- Complete context in one sentence or short paragraph
- Specific file paths, priorities, and actionable verbs
- Any critical constraints or requirements upfront

**What to exclude**:
- Vague language like "continue work" or "finish the task"
- Multiple options that require decision-making
- References to "above" or "previous sections" (command should be standalone)
- Conditional statements or prerequisites

**Purpose**:
This is THE instruction that the user will copy-paste to the next agent. It must be so clear and complete that the next agent can start working immediately without reading the entire milestone document first.

**Format**:
```
Continue implementation of [Feature/Task] by [specific action].
Start with [File/Function/Location] and [what to do].
Priority: [Priority Level]. Constraints: [Key constraint if any].
```

**Examples**:

[GOOD] **Good Direct Milestone Commands**:
```
Implement the remaining 3 pattern recognition functions in lib/Analysis/PatternMatcher.cpp
(lines 150-200). Start with matchConvolutionPattern() following the template from
matchMatmulPattern() at line 80. Priority: HIGH. Must maintain backward compatibility
with existing test cases in tests/analysis/pattern_test.cpp.
```

```
Fix the 5 failing tests in tests/transform/loop_fusion_test.cpp by updating the
LoopFusionPass transform logic in lib/Transform/LoopFusion.cpp lines 300-350.
The tests expect proper dependency checking before fusion. Priority: CRITICAL.
All other tests must remain passing.
```

```
Add LLVM lowering support for dsa.compute_fft operation. Implement the conversion
pattern in lib/Conversion/DSAToLLVM/ComputeOps.cpp following the structure of
dsa.compute_conv at line 450. Priority: MEDIUM. Target: make tests/lowering/fft_test.mlir pass.
```

[BAD] **Poor Direct Milestone Commands**:
```
Continue the work on pattern recognition that we discussed earlier.
```
*Why bad: Too vague, references earlier context, no specific starting point*

```
You could either finish the pattern matcher or work on the test cases,
whichever you think is more important.
```
*Why bad: Offers choices instead of clear direction, forces decision-making*

```
Fix the bugs mentioned in Section 4.
```
*Why bad: Requires reading other sections, not self-contained*

**Best Practices**:
1. Use imperative verbs: "Implement", "Fix", "Add", "Update", "Complete"
2. Include exact file paths and line ranges when possible
3. Reference similar existing code as templates
4. State the definition of "done" (e.g., "make X test pass")
5. Put the most critical constraint upfront if space is limited
6. Test the command: Could someone unfamiliar with the project understand what to do?
7. **MANDATORY**: Include specific test names that must pass to consider the task complete
8. **MANDATORY**: Reference expected failed tests and their current status

---

## Style Guidelines for Milestone Summaries

### Tone and Voice
- Write as an engineering manager briefing the next developer
- Professional but concise
- Focus on actionable information
- Avoid excessive enthusiasm or emoji (unless user specifically prefers them)

### Formatting Preferences
- Use tables for comparisons and metrics
- Use code blocks for commands or file paths
- Use lists for task breakdowns
- Keep sections scannable with clear headers

### Length Guidelines
- Entire summary: 500-1000 lines maximum
- Each section: 50-200 lines
- Individual task descriptions: 10-30 lines
- If longer, split into multiple focused summaries

### Content Integrity

**CRITICAL**: All information in the milestone summary must be accurate and based on reasonable analysis. This is especially true for time estimates.

**Don't**:
- **Fabricate hour estimations**: Never invent numbers for task completion times.
- **Guess randomly**: Avoid providing estimates without any basis.
- **Underestimate complexity**: Do not provide overly optimistic estimates that are unlikely to be met.

**Do**:
- **Provide realistic ranges**: If uncertain, use a range (e.g., "2-4 hours").
- **Base estimates on evidence**: Use past experience with similar tasks, complexity of the code, and number of files to be changed as a basis for your estimate.
- **State assumptions**: If an estimate depends on certain assumptions, state them clearly (e.g., "This estimate assumes the external API is stable").
- **Use "TBD" if unknown**: If you cannot form a reasonable estimate, it is better to state "Time estimate to be determined" (TBD) and explain why (e.g., "requires further investigation into the legacy module").

Honest and well-founded estimates are critical for building trust and ensuring the next agent can plan their work effectively. Fabricated numbers undermine the purpose of the milestone.

---

## Anti-Patterns to Avoid

**Don't**:
- Repeat information already in conversation history
- Include code snippets of completed features
- Write detailed implementation tutorials
- List every single file modified
- Describe obvious or standard procedures
- Create separate documentation files (unless required by project)

**Do**:
- Focus on what's NOT done and what's needed to continue
- Highlight non-obvious decisions and their context
- Point to specific locations where work should continue
- Provide enough context to avoid re-discovery work
- Make it easy for next agent to start immediately

---

## Validation Checklist

Before finalizing milestone summary, verify:
- [ ] Status metrics are current and accurate
- [ ] All critical rules are documented
- [ ] Unfinished tasks have clear priorities
- [ ] Code locations are specific (file + line ranges)
- [ ] Next steps are actionable and time-estimated
- [ ] Time estimates are realistic and not fabricated
- [ ] No duplicate information from completed work details
- [ ] Summary is under 1000 lines
- [ ] Quick start commands are tested
- [ ] **Direct Milestone Command is present and self-contained**
- [ ] **Direct Milestone Command includes specific file paths**
- [ ] **Direct Milestone Command uses imperative verbs**
- [ ] **Direct Milestone Command can be understood without reading other sections**
- [ ] **Direct Milestone Command specifies priority and constraints**

---

## Critical Requirement: Direct Milestone Command

**MANDATORY**: Every milestone summary MUST end with a Direct Milestone Command (Section 7).

This is the single most important element of the milestone because:
1. It enables immediate action - the user can copy-paste it to start the next session
2. It forces clarity - if you can't write a clear command, the task isn't well-defined
3. It prevents ambiguity - no interpretation needed, just execute
4. It saves time - next agent doesn't need to read 500+ lines to get started

**If you cannot write a clear Direct Milestone Command, the milestone is incomplete.**

---

## Usage Notes

This framework should be adapted based on:
- Complexity of the project
- Amount of remaining work
- Criticality of specific knowledge
- Time since last milestone

Not every section is mandatory - use judgment to include what's most valuable for continuation. **EXCEPT Section 7 (Direct Milestone Command) which is always required.**

---

## GitHub Issue Milestone Template

When creating a milestone as a GitHub issue, use this structure:

### Issue Title Format

Follow the project's 3-tag system:

```
[Component][SubArea][Issue #XX] <what-needs-to-be-done-next>
```

Or:
```
[Component][SubArea][PR #YY] <what-needs-to-be-done-next>
```

Where:
- `Component` - Primary component (CC, SIM, MAPPER, etc.)
- `SubArea` - Feature area (Temporal, Memory, etc.) - optional
- `[Issue #XX]` or `[PR #YY]` - Reference to parent issue/PR

**Title restrictions**:
- ✗ NO temporary planning terms: `Step X.Y`, `Week Z`, `Section K`, `Phase Y`
- ✗ NO dependencies in title beyond the source tag
- ✓ Focus on WHAT needs to be done next, not planning artifacts

**Good examples**:
- `[CC][Temporal][Issue #123] Implement remaining pattern matchers`
- `[SIM][CMSIS][PR #456] Complete test coverage for atomic lowering`
- `[TEST][Issue #789] Add unit tests for temporal PE`

**Bad examples**:
- `[CC][Temporal][Issue #123] Finished memory operations` (describes past, not future)
- `[CC][Milestone] Work continuation` (uses old [Milestone] tag instead of source)
- `[CC][Issue #123] Step 2.1: Add compute operations` (contains planning term)
- `[Temporal][Issue #123] Add feature` (SmallField without BigField - not allowed)

### Issue Labels

Always apply these labels:
- `milestone` - Primary label for milestone issues
- `continuation` - Indicates this continues previous work

### Issue Body Structure

```markdown
## Milestone Summary

**Parent Issue**: #<number>
**Branch**: `<branch-name>`
**Created**: <YYYY-MM-DD HH:MM>

---

## Current Status

### Progress Metrics
- Lines changed: +X/-Y
- Files modified: N
- Build status: PASSING/FAILING
- Tests: X passing, Y failing

### Completed Work
- [x] Task 1 (commit: `abc1234`)
- [x] Task 2

### Latest Commits
```
<git log --oneline -5 output>
```

---

## Remaining Tasks

### Priority 1: <Task Name>
**Difficulty**: LOW/MEDIUM/HIGH/COMPLEX
**Objective**: What needs to be accomplished
**Target files**:
- `/path/to/file.cpp:lines` - What to modify
**Expected outcome**: Tests to pass, behavior to achieve
**Implementation hints**: Patterns to follow, entry points

### Priority 2: <Task Name>
...

---

## Technical Insights

### Key Discovery: <Topic>
- **Finding**: What was learned
- **Implication**: How it affects implementation
- **Location**: `file:line`

---

## Code Navigation

| Purpose | File | Lines | Notes |
|---------|------|-------|-------|
| Main implementation | `/path/file` | X-Y | Description |
| Related tests | `/tests/file` | X-Y | Test patterns |

---

## Quick Start

```bash
git checkout <branch>
make all
llvm-lit -v build/tests/<path>
```

---

## Direct Milestone Command

> **Copy this to start the next session:**

<Self-contained instruction with file paths, priority, and specific action>
```

### Linking to Parent Issue

After creating the milestone issue, comment on the parent issue:

```markdown
Milestone created: #<milestone-issue-number>

Work continuation point created due to scope. See linked issue for:
- Current progress and remaining tasks
- Technical insights and code navigation
- Quick start commands for next session
```

This maintains traceability between the original issue and continuation work
