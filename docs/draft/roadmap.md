# Agentize Roadmap

## Current Implementation Status

### Completed Components (as of 2025-12-23)

#### Skills
- `commit-msg`: Creates meaningful git commits following project standards
- `open-issue`: Creates GitHub issues from conversation context with proper formatting
- `open-pr`: Creates pull requests with proper formatting

#### Commands
- `commit-msg.md`: Invokes the commit-msg skill
- `open-issue.md`: Invokes the open-issue skill

#### Infrastructure
- Basic project structure with `claude/` directory
- Testing framework (`tests/` folder with shell scripts)
- Template system for SDK generation
- Documentation structure (`docs/` folder)
- Git message tag standards (`docs/git-msg-tags.md`)

---

## Roadmap Overview

The roadmap is divided into two major phases based on the draft plans:

1. **Phase 1: Plan Generation Workflow** (from `plan-workflow.md`)
2. **Phase 2: Plan Implementation Workflow** (from `plan-impl.md`)

---

## Phase 1: Plan Generation Workflow

### Goal
Enable AI-assisted planning where user requirements are transformed into well-vetted implementation plans through multiple agent personas.

### Components to Implement

#### 1.1 Novel-Proposer Agent Persona
**Status:** Not Started
**Priority:** High
**Description:** Agent persona that breaks down user requirements into uncommon/creative development plans.

**Implementation Requirements:**
- Create skill: `claude/skills/novel-proposer/SKILL.md`
- Define persona characteristics (creativity, unconventional thinking)
- Specify input format (user requirements in markdown or CLI)
- Specify output format (development plan proposals)
- Include examples of plan breakdowns

**Dependencies:** None

---

#### 1.2 Critique Agent Persona
**Status:** Not Started
**Priority:** High
**Description:** Agent persona that reviews proposed plans for feasibility, identifying potential issues and concerns.

**Implementation Requirements:**
- Create skill: `claude/skills/critique/SKILL.md`
- Define persona characteristics (critical thinking, risk assessment)
- Specify input format (novel-proposer's output)
- Specify output format (feasibility assessment with concerns/approvals)
- Include evaluation criteria (technical feasibility, resource requirements, risks)

**Dependencies:** 1.1 Novel-Proposer Agent

---

#### 1.3 Synthesis Agent Persona
**Status:** Not Started
**Priority:** High
**Description:** Third-party agent that synthesizes consensus and conflicts from novel-proposer and critique agents into a final plan.

**Implementation Requirements:**
- Create skill: `claude/skills/synthesis/SKILL.md`
- Define persona characteristics (objective, balanced, integrative)
- Specify input format (outputs from both novel-proposer and critique)
- Specify output format (final synthesized plan with consensus/conflicts highlighted)
- Include conflict resolution strategies

**Dependencies:** 1.1 Novel-Proposer Agent, 1.2 Critique Agent

---

#### 1.4 Plan-an-Issue Command
**Status:** Not Started
**Priority:** High
**Description:** Command that orchestrates the entire planning workflow and creates a GitHub issue upon approval.

**Implementation Requirements:**
- Create command: `claude/commands/plan-an-issue.md`
- Orchestrate workflow: User input → Novel-proposer → Critique → Synthesis → User approval
- Integrate with existing `open-issue` skill for GitHub issue creation
- Handle user approval/rejection flow
- Support both markdown file and direct CLI input for requirements

**Dependencies:** 1.1, 1.2, 1.3, and existing `open-issue` skill

---

## Phase 2: Plan Implementation Workflow

### Goal
Enable systematic implementation of approved plans with test-driven development, milestone tracking, and code review.

### Components to Implement

#### 2.1 Plan Adjuster Agent Persona
**Status:** Not Started
**Priority:** Medium
**Description:** Agent persona that adjusts the plan implementation based on difficulties encountered during development.

**Implementation Requirements:**
- Create skill: `claude/skills/plan-adjuster/SKILL.md`
- Define persona characteristics (adaptive, pragmatic, solution-oriented)
- Specify input format (current plan + encountered difficulties)
- Specify output format (adjusted plan)
- Include adjustment criteria and boundaries

**Dependencies:** Phase 1 completion

---

#### 2.2 Towards-Next-Milestone Skill
**Status:** Not Started
**Priority:** High
**Description:** Skill that implements the plan step by step, stopping at 800 lines or completion.

**Implementation Requirements:**
- Create skill: `claude/skills/towards-next-milestone/SKILL.md`
- Define milestone criteria (800 lines without completion)
- Specify milestone document format
- Include progress tracking mechanism
- Define test-driven development approach
- Handle session continuation logic

**Dependencies:** Phase 1 completion

---

#### 2.3 Code Reviewer Agent Persona
**Status:** Not Started
**Priority:** Medium
**Description:** Agent persona that reviews code quality and suggests improvements before PR creation.

**Implementation Requirements:**
- Create skill: `claude/skills/code-reviewer/SKILL.md`
- Define persona characteristics (thorough, quality-focused, constructive)
- Specify review criteria (code quality, best practices, maintainability)
- Specify input format (completed implementation code)
- Specify output format (review feedback with suggestions)
- Include code quality standards

**Dependencies:** 2.2 Towards-Next-Milestone Skill

---

#### 2.4 Issue2Impl Command
**Status:** Not Started
**Priority:** High
**Description:** Command that orchestrates the entire implementation workflow from GitHub issue to pull request.

**Implementation Requirements:**
- Create command: `claude/commands/issue2impl.md`
- Orchestrate workflow:
  1. Fork new branch from main
  2. Step 0: Update documentation
  3. Step 1: Create/update test cases (TDD)
  4. Step 2: Execute `towards-next-milestone` skill
  5. Step 3: Handle milestone continuation (user intervention)
  6. Step 4: Code reviewer reviews quality
  7. Step 5: Create pull request via `open-pr` skill
- Integrate with existing `open-pr` skill
- Handle multi-session implementation flow
- Support plan adjuster integration

**Dependencies:** 2.1, 2.2, 2.3, and existing `open-pr` skill

---

## Phase 3: Testing and Documentation (Future)

### Components to Implement

#### 3.1 Comprehensive Test Suite
**Status:** Not Started
**Priority:** Medium
**Description:** Complete test coverage for all skills and commands.

**Implementation Requirements:**
- Test scripts for each persona agent skill
- Integration tests for `plan-an-issue` workflow
- Integration tests for `issue2impl` workflow
- End-to-end workflow tests
- Add to `tests/` directory with shell scripts

**Dependencies:** Phase 1 and Phase 2 completion

---

#### 3.2 Documentation Updates
**Status:** Not Started
**Priority:** Low
**Description:** Complete documentation for all new features.

**Implementation Requirements:**
- Update main README.md with workflow diagrams (already partially done)
- Create detailed user guides for each command
- Document agent persona characteristics and behaviors
- Add troubleshooting guide
- Create examples and tutorials

**Dependencies:** Phase 1 and Phase 2 completion

---

## Implementation Priority Order

### Must-Have (Core Workflow)
1. Novel-Proposer Agent (1.1)
2. Critique Agent (1.2)
3. Synthesis Agent (1.3)
4. Plan-an-Issue Command (1.4)
5. Towards-Next-Milestone Skill (2.2)
6. Issue2Impl Command (2.4)

### Should-Have (Quality & Refinement)
7. Plan Adjuster Agent (2.1)
8. Code Reviewer Agent (2.3)
9. Test Suite (3.1)

### Nice-to-Have (Enhancement)
10. Documentation Updates (3.2)

---

## Success Metrics

### Phase 1 Success Criteria
- Users can provide requirements via markdown file or CLI
- Novel-proposer generates creative development plans
- Critique agent provides feasibility assessment
- Synthesis agent produces coherent final plan
- User can approve/reject plans
- Approved plans become GitHub issues automatically

### Phase 2 Success Criteria
- GitHub issues can be converted to implementation workflow
- New branch is created automatically
- Documentation is updated first
- Tests are written before implementation (TDD)
- Implementation proceeds in manageable milestones (800 lines)
- Code review occurs before PR creation
- PR is created automatically with proper formatting

---

## Technical Considerations

### Design Principles
- Keep rules project-neutral (from CLAUDE.md)
- All paths relative to project root, no `cd` usage
- Each folder should have README.md describing purpose
- Follow existing skill/command structure patterns
- Use GitHub CLI (`gh`) for issue/PR operations

### Architecture Notes
- Agent personas are implemented as skills
- Commands orchestrate multiple skills
- Each skill should be modular and reusable
- Skills should have clear input/output contracts
- Error handling must be robust and user-friendly

### Testing Strategy
- Shell scripts in `tests/` directory
- Run all tests via `make test`
- Each module testable via `tests/*.sh` files
- Integration tests for end-to-end workflows

---

## Timeline Estimate

**Note:** This is a high-level estimate. Actual implementation timeline depends on available resources and priorities.

- **Phase 1 (Plan Generation):** 4-6 major tasks
  - Estimated complexity: Medium-High
  - Critical path: 1.1 → 1.2 → 1.3 → 1.4

- **Phase 2 (Plan Implementation):** 4 major tasks
  - Estimated complexity: High
  - Critical path: 2.2 → 2.4 (2.1 and 2.3 can be developed in parallel)

- **Phase 3 (Testing & Docs):** 2 tasks
  - Estimated complexity: Medium
  - Can be done incrementally

---

## Next Steps

### Immediate Actions
1. Create skill structure for Novel-Proposer Agent
2. Define persona characteristics and workflows
3. Implement basic plan breakdown logic
4. Test with sample requirements

### Short-term Goals
1. Complete Phase 1 core components (1.1-1.4)
2. Test plan generation workflow end-to-end
3. Gather user feedback on plan quality

### Long-term Goals
1. Complete Phase 2 implementation workflow
2. Achieve full test coverage
3. Create comprehensive documentation
4. Collect usage data and iterate on improvements

---

## Open Questions

1. **Multi-language Support:** Should planning agents support languages beyond what's in templates?
2. **Plan Storage:** Should plans be stored locally before GitHub issue creation?
3. **Version Control:** How to handle plan versioning if requirements change?
4. **Milestone Format:** What should milestone documents contain? Partial code? Progress notes?
5. **Review Automation:** Should code reviewer agent auto-fix issues or just suggest?
6. **User Intervention:** How to gracefully handle user intervention points in multi-session workflows?

---

## Risk Assessment

### High Risks
- Agent persona quality may vary based on underlying model capabilities
- 800-line milestone threshold may not suit all project types
- Multi-session workflow coordination may be complex

### Mitigation Strategies
- Extensive testing with diverse project types
- Make milestone threshold configurable
- Clear session state management and documentation
- User feedback loops at critical decision points

---

## Revision History

- 2025-12-23: Initial roadmap created based on `plan-workflow.md` and `plan-impl.md`
