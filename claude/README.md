# Claude Code Configuration

This directory configures Claude Code for your project, providing automated workflows for issue resolution, idea-to-implementation pipelines, and code quality enforcement.

## Directory Structure

```
.claude/
├── CLAUDE.md           # Project-level instructions (loaded automatically)
├── settings.json       # Permission and hooks configuration
├── agents/             # Specialized subagents spawned by commands
├── commands/           # Slash commands (/command-name)
├── hooks/              # Lifecycle hooks (SessionStart, PostToolUse, etc.)
├── rules/              # Behavioral rules (auto-loaded or path-specific)
└── skills/             # Reference data and templates
```

## Component Types

| Type | Location | Purpose | Invocation |
|------|----------|---------|------------|
| **Commands** | `commands/*.md` | Entry points for workflows | `/command-name` |
| **Agents** | `agents/*.md` | Specialized subprocesses | Spawned by Task tool |
| **Skills** | `skills/*/SKILL.md` | Reference tables and templates | Skill tool |
| **Rules** | `rules/*.md` | Behavioral constraints | Auto-loaded or path-matched |
| **Hooks** | `hooks/*.sh` | Deterministic lifecycle behavior | Configured in settings.json |

## Meta-Commands

### /issue2impl

End-to-end workflow for resolving GitHub issues with code review cycles.

**3-Tier Triage System**: The workflow adapts based on issue complexity:

| Tier | Criteria | Workflow |
|------|----------|----------|
| **Fast** | Single file, doc-only, <50 lines, `quick-fix` label | Skip docs/planning, simplified review |
| **Standard** | Default | Full 9-phase workflow |
| **Extended** | Multi-component, >1500 lines, `complex` label | Add architecture review |

Note: Extended tier overrides fast tier if both criteria match.

```mermaid
flowchart TB
    Start([/issue2impl]) --> P1

    subgraph P1[Phase 1: Input Validation]
        IV[input-validator]
    end

    subgraph P2[Phase 2: Issue Analysis]
        IA[issue-analyzer]
    end

    subgraph P3[Phase 3: Documentation]
        DA[doc-architect]
    end

    subgraph P4[Phase 4: Planning]
        PM[Plan Mode]
        WR1[workflow-reference skill]
        PM --> WR1
    end

    subgraph P5[Phase 5: Implementation]
        IMP[Implementation]
        SIZE{Size Check}
        MG[milestone-generator]
        PJM1[project-manager]
        IMP --> SIZE
        SIZE -->|Red Zone| MG
        MG --> PJM1
    end

    subgraph P6[Phase 6: Code Review]
        CR[code-reviewer]
        CI[ci-checks skill]
        CI -.-> CR
    end

    subgraph P7[Phase 7: Commit & PR]
        PCG[pre-commit-gate]
        GC[git-commit]
        PRNODE[Create PR]
        PRT[pr-templates skill]
        PCG --> GC
        GC --> PRNODE
        PRT -.-> PRNODE
    end

    subgraph P8[Phase 8: Remote Review]
        RR[Remote Review]
        RPC[resolve-pr-comment]
        RR --> RPC
    end

    subgraph P9[Phase 9: Finalize]
        URI[update-related-issues]
        SUM[Summary]
        URI --> SUM
    end

    P1 --> P2
    P2 --> P3
    P3 --> P4
    P4 --> P5
    P5 -->|Green Zone| P6
    PJM1 -.->|Partial PR| P6
    P6 -->|Score >= 81| P7
    P6 -->|Score < 81| IMP
    P7 -->|PASS| P8
    PCG -->|FAIL| P6
    P8 --> P9
```

**Component Integration:**

| Phase | Components | Purpose |
|-------|------------|---------|
| 1 | `input-validator` (Haiku) | Validate issue number, branch, dependencies |
| 2 | `issue-analyzer` | Analyze issue requirements and codebase |
| 3 | `doc-architect` | Interactive documentation brainstorming |
| 4 | `workflow-reference` skill | Size thresholds, L1/L2 tag inference |
| 5 | `milestone-generator` + `project-manager` | Create continuation issues when size exceeded |
| 6 | `code-reviewer` (Opus) + `ci-checks` skill | Skeptical code review with scoring |
| 7 | `pre-commit-gate` (Haiku) + `/git-commit` + `pr-templates` skill | Verify build, commit, create PR |
| 8 | `/resolve-pr-comment` | Handle remote review feedback |
| 9 | `/update-related-issues` | Update issue chain, generate summary |

---

### /feat2issue

Transform design ideas into actionable GitHub issues through interactive brainstorming.

```mermaid
flowchart TB
    Start([/feat2issue]) --> P0

    subgraph P0[Phase 0: Input Validation]
        IV2[input-validator]
    end

    subgraph P1[Phase 1: Three-Agent Brainstorming]
        CP[idea-creative-proposer]
        CC[idea-critical-checker]
        CA[idea-comprehensive-analyzer]
        CP --> CC
        CC --> CA
        CA -->|REVISION_NEEDED| CP
    end

    subgraph P2[Phase 2: Issue Research]
        IR[issue-researcher]
    end

    subgraph P3[Phase 3: Doc Research]
        DR[doc-researcher]
    end

    subgraph P4[Phase 4: Planning]
        PM2[Plan Mode]
    end

    subgraph P5[Phase 5: Implementation]
        DI[Create Doc Issue]
        PJM2A[project-manager A]
        GC2[git-commit]
        DPR[Create Doc PR]
        IC[issue-creator]
        IT[issue-templates skill]
        PJM2B[project-manager B]
        DI --> PJM2A
        PJM2A --> GC2
        GC2 --> DPR
        DPR --> IC
        IT -.-> IC
        IC --> PJM2B
    end

    subgraph P6[Phase 6: Cleanup]
        URI2[update-related-issues]
        SUM2[Summary]
        URI2 --> SUM2
    end

    P0 --> P1
    P1 -->|DESIGN_CONFIRMED| P2
    P1 -->|DESIGN_ABANDONED| Stop((Stop))
    P2 --> P3
    P3 --> P4
    P4 --> P5
    P5 --> P6
```

**Three-Agent Brainstorming Chain:**

```
User Idea -> creative-proposer (divergent) -> critical-checker (convergent) -> comprehensive-analyzer (synthesis) -> User
                                                                                    |
                                                                         REVISION_NEEDED -> Loop back
```

| Agent | Model | Role |
|-------|-------|------|
| `idea-creative-proposer` | Opus | Generate bold alternatives, research prior art |
| `idea-critical-checker` | Opus | Fact-check claims, expose fallacies, challenge assumptions |
| `idea-comprehensive-analyzer` | Opus | Synthesize proposals and critiques, make recommendation |

---

## Agent-Command Coordination

```
Commands (Entry Points)
    │
    ├── /issue2impl ─┬─> input-validator
    │                   ├─> issue-analyzer
    │                   ├─> doc-architect
    │                   ├─> code-reviewer
    │                   ├─> milestone-generator ──> project-manager
    │                   └─> pre-commit-gate
    │
    ├── /feat2issue ┬─> input-validator
    │                   ├─> idea-creative-proposer
    │                   ├─> idea-critical-checker
    │                   ├─> idea-comprehensive-analyzer
    │                   ├─> issue-researcher
    │                   ├─> doc-researcher
    │                   ├─> issue-creator ──> project-manager
    │                   └─> project-manager (doc issue)
    │
    ├── /gen-milestone ─┬─> milestone-generator
    │                   └─> project-manager
    │
    └── /git-commit ────> (follows git-commit-format.md rule)
```

**Key Constraint:** Subagents cannot spawn other subagents. The main thread must spawn `project-manager` after receiving issue numbers from `milestone-generator` or `issue-creator`.

## Skills Reference

| Skill | Content | Used By |
|-------|---------|---------|
| `workflow-reference` | Size thresholds, L1/L2 tag inference, error handling | `/issue2impl` (Phases 4, 5, 7) |
| `pr-templates` | PR body templates, summary templates | `/issue2impl` (Phase 7, 9) |
| `issue-templates` | Feature, sub-issue, doc, refactor templates | `/feat2issue` (Phase 5) |
| `ci-checks` | Local CI validation (format, special chars, links) | Code review phase |

## Rules Summary

| Rule | Scope | Purpose |
|------|-------|---------|
| `language.md` | Always | English-only for all repository content |
| `git-commit-format.md` | `/git-commit` | Commit message format with tags |
| `issue-pr-format.md` | Issue/PR creation | 3-tag title system, SWE-Bench format |
| `milestone-guide.md` | Milestone generation | Structured milestone issue format |
| `project-board-integration.md` | Issue creation | Every issue must be added to GitHub Project |
| `custom-project-rules.md` | User-defined | Project-specific coding conventions |
| `custom-workflows.md` | User-defined | Project-specific workflows |

## Customization

The Agentize SDK is designed to be customizable for different project types:

1. **Core Rules**: Pre-configured, project-neutral rules in `rules/*.md`
2. **Custom Rules**: Add project-specific rules in:
   - `rules/custom-project-rules.md` - Coding conventions, testing requirements
   - `rules/custom-workflows.md` - Development workflows, deployment processes

3. **Component Tags**: Configure L1/L2 tags in `.claude/CLAUDE.md` to match your project structure

See `CUSTOMIZATION_GUIDE.md` for detailed instructions.

## Quick Reference

```bash
# Resolve an issue end-to-end
/issue2impl 123

# Transform idea into implementation issues
/feat2issue "Add user authentication feature"
/feat2issue ./docs/draft/my-idea.md

# Generate milestone for incomplete work
/gen-milestone

# Create commit following project standards
/git-commit

# Update related issues based on codebase state
/update-related-issues 123

# Resolve PR review comments
/resolve-pr-comment
```

## Installation

This configuration was installed using the Agentize SDK. To install in another project:

```bash
cd agentize/
make agentize \
  AGENTIZE_MASTER_PROJ=/path/to/target/project \
  AGENTIZE_PROJ_NAME="My Project" \
  AGENTIZE_MODE=port
```

See the main Agentize README for more installation options.

## Updating Your Configuration

To update to the latest Agentize SDK version:

```bash
cd agentize/
make agentize \
  AGENTIZE_MASTER_PROJ=/path/to/your-project \
  AGENTIZE_MODE=update
```

### What Happens During Update

1. **Backup Created**: `.claude.backup.YYYYMMDD-HHMMSS/` preserves your current state
2. **SDK Files Updated**: Agents, commands, skills, hooks, and SDK rules are replaced
3. **User Files Preserved**: `custom-project-rules.md` and `custom-workflows.md` are never touched
4. **Templated Files Prompted**: For files like `CLAUDE.md` with project-specific content, you'll be asked to review changes
5. **Orphans Reported**: Files in your `.claude/` that no longer exist in the SDK are reported (but not deleted)

### File Ownership Model

| Category | Examples | Update Behavior |
|----------|----------|-----------------|
| SDK-owned | `agents/*.md`, `commands/*.md`, `rules/git-commit-format.md` | Replaced |
| User-owned | `rules/custom-project-rules.md`, `rules/custom-workflows.md` | Preserved |
| Templated | `CLAUDE.md`, `git-tags.md`, `settings.json` | Interactive prompt |

### Rollback

If something goes wrong:
```bash
rm -rf .claude
mv .claude.backup.YYYYMMDD-HHMMSS .claude
```

