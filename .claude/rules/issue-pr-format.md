# Issue and PR Format Guidelines

This rule defines the standard formats for GitHub Issues and Pull Requests in the DSA Stack project.

## SWE-Bench Compatibility

Our issue templates follow the [SWE-Bench](https://www.swebench.com/) format to optimize for AI-assisted code generation. SWE-Bench is the industry-standard benchmark for evaluating LLMs on real-world software engineering tasks.

### Key SWE-Bench Concepts

| Concept | Description | Our Implementation |
|---------|-------------|-------------------|
| `problem_statement` | Issue title + body describing the problem | "Problem Statement" field |
| `Expected Behaviour` | What should happen | "Expected Behaviour" field |
| `Observed Behaviour` | What actually happens (bugs) | "Observed Behaviour" field |
| `FAIL_TO_PASS` | Tests that should pass after fix | "Test Plan" / "Test Verification" field |
| `PASS_TO_PASS` | Tests that must remain passing | Included in test fields |
| `hints_text` | Implementation hints | "Implementation Hints" field |
| `interface` | API/interface affected | "Interface Specification" field |

### Why SWE-Bench Format?

1. **AI Training**: Most coding LLMs (Claude, GPT, etc.) are trained/evaluated on SWE-Bench
2. **Structured Input**: Clear sections help AI understand requirements
3. **Test-Driven**: Explicit test expectations enable verification
4. **Reproducibility**: Minimal examples and clear steps aid debugging

## 3-Tag Title System

### Core Concept

Titles use a flexible 3-tag system: `[BigField][SmallField][SourceTag] Description`

- **BigField** (Component): Primary component (CC, SIM, MAPPER, etc.)
- **SmallField** (SubArea): Feature area within component (Temporal, Memory, etc.)
- **SourceTag**: Reference to triggering issue or PR (`[Issue #N]`, `[PR #N]`)

### Allowed Formats

| Format | Example | Use Case |
|--------|---------|----------|
| `[Big][Small][Source]` | `[CC][Temporal][Issue #123] Continue implementation` | Full context |
| `[Big][Small]` | `[CC][Temporal] Add new feature` | No source reference |
| `[Big][Source]` | `[CC][Issue #456] Fix memory handling` | No sub-area |
| `[Big]` | `[TEST] Add unit tests` | Standalone component |
| `[Source]` | `[Issue #89] Update dependencies` | Meta/cross-cutting |

### Constraint

**NOT ALLOWED**: `[Small]` without `[Big]` (SubArea requires Component, like L2 requires L1)

## Issue Title Format

Common patterns:

```
[Component][SubArea] Short description
[Component] Short description
[Component][Issue #XX] Continue work from issue #XX
[Component][SubArea][Issue #XX] Continue specific work
```

### Component Tags (Primary)

| Tag | Description |
|-----|-------------|
| `[DSACC]` | Top-level C compiler |
| `[DSA++]` | Top-level C++ compiler |
| `[CC]` | DSA compiler (MLIR to Handshake+DSA) |
| `[SIM]` | Event-driven MLIR simulator |
| `[MAPPER]` | Place and Route tool |
| `[HWGEN]` | Hardware generation tool |
| `[GUI]` | Human-computer interface |
| `[TEST]` | Testing and validation |
| `[PERF]` | Performance modeling |
| `[DOCS]` | Documentation |
| `[HW]` | RTL/Netlist hardware design |
| `[DV]` | Design verification |
| `[PD]` | Physical design |
| `[PROTO]` | FPGA prototyping |
| `[RUNTIME]` | Firmware and driver |
| `[SIGNOFF]` | Packaging and manufacturing |

### Sub-Area Tags (Optional, Second Position)

| Tag | Description |
|-----|-------------|
| `[Temporal]` | Temporal PE/Switch features |
| `[Memory]` | Memory subsystem and addressing |
| `[CMSIS]` | CMSIS-DSP workload testing |
| `[SPEC2017]` | SPEC2017 benchmark testing |
| `[Greedy]` | Greedy scheduling algorithm |
| `[SimAnneal]` | Simulated Annealing algorithm |
| `[LLM]` | LLM-based scheduling |
| `[RL]` | Reinforcement learning scheduler |

### Issue Title Examples

```
[CC][Temporal] Add dsa.instance operation for module instantiation
[SIM][CMSIS] Fix memory leak in vector multiply test
[MAPPER][Greedy] Improve edge routing heuristics
[TEST] Add unit tests for temporal PE
[DOCS] Update DSA dialect reference
[RFC] Design spatial memory addressing for 2D arrays
```

## PR Title Format

All PRs must follow this title format:

```
[Component][SubArea][Issue #XX] Short description
```

Or with single component only:
```
[Component][Issue #XX] Short description
```

**Key difference from Issue titles**: PR titles include `[Issue #XX]` at the END of the tag sequence.

### PR Title Examples

```
[CC][Temporal][Issue #121] Add dsa.instance operation
[SIM][CMSIS][Issue #45] Fix buffer overflow in allocator
[TEST][Issue #85] Add unit tests for temporal PE
[DOCS][Issue #90] Update DSA dialect reference
```

## Issue Types and Templates

### 1. Feature Request

For new functionality proposals. Focus on **problem** and **requirements**, not implementation.

**Required sections** (SWE-Bench aligned):
- Problem Statement (title + context)
- Current Behaviour (what happens now)
- Expected Behaviour (what should happen after)
- Acceptance Criteria (checkboxes)
- Test Plan (FAIL_TO_PASS + PASS_TO_PASS)
- Dependencies & Relationships

**Optional sections**:
- Interface Specification
- Design Ideas
- Implementation Hints

### 2. Bug Report

For unexpected behavior or errors.

**Required sections** (SWE-Bench aligned):
- Problem Statement (title + summary)
- Steps to Reproduce (with code examples)
- Expected Behaviour
- Observed Behaviour (with error messages)
- Environment (version, commit, OS)

**Optional sections**:
- Test Verification (FAIL_TO_PASS tests)
- Affected Interface
- Implementation Hints
- Logs/Backtrace

### 3. Sub-Issue

For subtasks of larger features. Must reference a parent issue.

**Required sections** (SWE-Bench aligned):
- Parent Issue reference
- Problem Statement
- Expected Behaviour
- Files to Modify
- Test Plan
- Acceptance Criteria
- Dependencies

**Optional sections**:
- Current Behaviour
- Interface Specification
- Implementation Hints

### 4. Discussion / RFC

For design discussions before implementation.

**Required sections**:
- Problem Statement
- Options Considered
- Open Questions

## PR Structure

### Required Sections

1. **Summary**: Brief description of changes (MUST include linking keyword - see below)
2. **Changes Made**: File-by-file breakdown
3. **Test Plan**: Verification checklist
4. **Related Issues & PRs**: Dependency table

### GitHub Auto-Linking Requirement

**CRITICAL**: For GitHub to automatically link PRs to issues, the Summary section MUST include a linking keyword line.

**Required format in Summary (single issue):**
```markdown
## Summary

Resolves #123

Brief description...
```

**Required format for MULTIPLE issues:**

Per [GitHub docs](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue), **each issue requires its own keyword**:

```markdown
## Summary

Resolves #10, resolves #123, resolves #145

Brief description...
```

[WRONG] Single keyword for multiple issues:
```markdown
Resolves #10, #123, #145
```

[CORRECT] Keyword for each issue:
```markdown
Resolves #10, resolves #123, resolves #145
```

**Cross-repository syntax:**
```markdown
Resolves #10, resolves octo-org/octo-repo#100
```

**Supported keywords** (per [GitHub docs](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue)):
- `close`, `closes`, `closed`
- `fix`, `fixes`, `fixed`
- `resolve`, `resolves`, `resolved`

**Important**: The "Related Issues & PRs" table is for human documentation only - it does NOT trigger GitHub's auto-linking feature. You need BOTH:
1. `Resolves #XXX` line(s) in Summary -> enables GitHub auto-linking
2. Relationship table -> provides human-readable documentation

### PR Relationships Table

Use this format to document PR relationships:

```markdown
| Relationship | Issue/PR | Description |
|--------------|----------|-------------|
| **Resolves** | #121 | Primary issue |
| **Partial for** | #120 | Does not fully close |
| **Depends on** | PR #126 | Must merge first |
| **Related to** | #91 | Context/reference |
```

## Dependency Patterns

### Issue Dependencies

```markdown
## Dependencies & Relationships

- **Depends on**: #123, #124 (must be completed first)
- **Blocked by**: #99 (upstream issue blocking this)
- **Parent**: #120 (this is a sub-issue)
- **Related to**: #91 (shared context, not blocking)
- **Blocks**: #125, #126 (waiting on this)
- **Successor**: TBD (follow-up work planned)
```

### PR Dependencies

Use the relationship table format shown above. Common patterns:

- `Resolves #X` - PR fully closes issue X
- `Partial for #X` - PR makes progress but doesn't close
- `Depends on #Y` - Another PR must merge first
- `Related to #Z` - Related context or discussion

## Label Assignment

**Important**: GitHub issue forms do NOT automatically assign labels based on dropdown selections. Labels must be added manually or by AI agents.

### Template Default Labels
Issue templates only auto-assign labels listed in the template's `labels:` array (e.g., `enhancement`, `bug`, `sub-issue`).

### Component Labels (Internal)

Labels use `L1:` and `L2:` prefixes internally for GitHub Project tracking, even though titles do not:
- Title: `[CC][Temporal] Description`
- Labels: `L1:CC`, `L2:Temporal`

This separation keeps titles clean while maintaining structured project board integration.

### Label Assignment
Labels must be added manually based on:
- **Title tags**: Extract component from `[CC][Temporal]` → labels `L1:CC`, `L2:Temporal`
- **File inference**: Determine from files being modified

### Agent Responsibility
When AI agents create issues or PRs, they MUST:
1. Extract component tags from title (e.g., `[CC][Temporal]`)
2. Add corresponding `L1:*` and `L2:*` labels explicitly via `gh issue create --label`
3. Include labels in the `--label` flag, not rely on auto-assignment

**Title → Label Mapping:**
- `[CC]` → `L1:CC`
- `[SIM]` → `L1:SIM`
- `[Temporal]` → `L2:Temporal`
- `[Memory]` → `L2:Memory`

## Prohibited Patterns

### In Issue Titles

- **No SmallField without BigField** (3-tag system constraint):
  - [BAD] `[Temporal] Add feature` (SubArea without Component)
  - [BAD] `[Memory][Issue #123]` (SubArea without Component)
  - [GOOD] `[CC][Temporal] Add feature`
  - [GOOD] `[CC][Memory][Issue #123]`

- **No old [Handoff] tag** - use source references:
  - [BAD] `[CC][Handoff] Continue work` (generic handoff tag)
  - [GOOD] `[CC][Issue #123] Continue implementation`
  - [GOOD] `[CC][Temporal][PR #456] Continue from PR`

- No `L1:` or `L2:` prefixes in tags - use clean tags like `[CC]`, `[Temporal]`:
  - [BAD] `[L1:CC][L2:Temporal] Add compute operation` (uses L1:/L2: prefix)
  - [GOOD] `[CC][Temporal] Add compute operation`

- No version numbers: `[v1.2]` - use labels instead
- No dates: `[2024-01]` - use milestones
- No status: `[WIP]`, `[DONE]` - use labels/project status

- **No temporary planning references**: `Step X.Y`, `Week Z`, `Section K`, `Phase Y`:
  - [BAD] `[CC][Temporal] Step 2.1: Add compute operation`
  - [BAD] `[MAPPER] Week 3: Implement routing algorithm`
  - [BAD] `[SIM] Section 4: Memory simulation`
  - [BAD] `[TEST] Phase 2: Add integration tests`
  - [GOOD] `[CC][Temporal] Add compute operation`
  - [GOOD] `[MAPPER] Implement routing algorithm`

### In PR Titles

Same prohibitions as Issue Titles apply to PR titles.

### In Issue/PR Dependency Specifications

- **Dependencies MUST be in body, not title**: All issue/PR dependencies must be specified in the body using `#<number>` format
  - Dependencies should appear in:
    - Issue body: "Dependencies & Relationships" section
    - PR body: "Related Issues & PRs" table
  - [BAD] Title: `[CC][Depends on #123] Add new feature`
  - [GOOD] Title: `[CC] Add new feature`, Body: `Depends on: #123`

### In PR Content

- **No local code review scores** - These are internal metrics
- No sensitive data or credentials
- No absolute paths from local machines

## Integration with AI Workflows

### When Creating Issues

Agents and commands that create issues MUST:
1. Use the appropriate template structure
2. Include component tags in title (e.g., `[CC][Temporal]`)
3. Add corresponding `L1:*` and `L2:*` labels via `--label` flag
4. Specify dependencies explicitly in body

### When Creating PRs

Agents and commands that create PRs MUST:
1. Use title format: `[Component][SubArea][Issue #XX] Description`
2. **Include `Resolves #XXX` line in Summary section** (for GitHub auto-linking)
3. Include relationship table (for human documentation)
4. NOT include code review scores in body
5. Reference primary issue in body

### Relevant Tools

| Tool | Creates | Template |
|------|---------|----------|
| `handoff-generator` | Sub-issues | Sub-Issue template |
| `/issue2impl` | PRs | PR template |
| `/gen-handoff` | Sub-issues | Sub-Issue template |
