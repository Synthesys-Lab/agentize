# Test: Code Review Agent

Test coverage for the code-review agent created in issue #38.

## Module Under Test

`.claude/agents/code-quality-reviewer.md` - Comprehensive code review agent using Opus model

## Test Status

**Status**: To test (dogfooding)

## Test Cases

### TC-1: Agent Configuration

**Test**: Verify agent YAML frontmatter is correct

**Validation**:
- [ ] `name: code-quality-reviewer` is set
- [ ] `description` is clear and actionable
- [ ] `tools: Read, Grep, Glob, Bash` are specified
- [ ] `model: opus` is specified
- [ ] `skills: review-standard` is specified

**Expected**: Agent configuration matches specification in AGENT.md

---

### TC-2: Agent Invocation

**Test**: Verify agent can be invoked via Task tool

**Validation**:
- [ ] Agent can be called with `Task tool` and `subagent_type='code-quality-reviewer'`
- [ ] Agent initializes with Opus model
- [ ] Agent loads review-standard skill
- [ ] Agent has access to specified tools

**Expected**: Agent starts successfully and is ready to execute

---

### TC-3: Isolated Context Execution

**Test**: Verify agent runs in isolated context

**Validation**:
- [ ] Agent does not have access to parent conversation history
- [ ] Agent workspace is clean
- [ ] Agent returns only final report to parent

**Expected**: Agent operates independently from parent conversation

---

### TC-4: Review Execution

**Test**: Verify agent performs code review correctly

**Validation**:
- [ ] Agent validates current branch (not main)
- [ ] Agent gets changed files
- [ ] Agent gets full diff
- [ ] Agent applies review-standard skill (all 3 phases)
- [ ] Agent generates structured report

**Expected**: Agent produces complete review report with all phases

---

### TC-5: Error Handling

**Test**: Verify agent handles error cases gracefully

**Validation**:
- [ ] Detects when on main branch and stops
- [ ] Detects when no changes exist and stops
- [ ] Detects when not in git repo and stops
- [ ] Provides clear error messages

**Expected**: Agent provides helpful error messages and stops execution appropriately

---

### TC-6: Long Context Handling

**Test**: Verify Opus model handles large diffs

**Validation**:
- [ ] Agent successfully processes diffs > 10 files
- [ ] Agent successfully processes diffs > 500 lines
- [ ] Agent completes within timeout (600s)
- [ ] Agent provides thorough analysis even for large changes

**Expected**: Agent leverages Opus's long context for comprehensive reviews

---

### TC-7: Comparison with Command

**Test**: Compare agent review vs command review on same diff

**Validation**:
- [ ] Both apply same review-standard skill
- [ ] Both produce equivalent Phase 1 findings
- [ ] Both produce equivalent Phase 2 findings
- [ ] Both produce equivalent Phase 3 findings
- [ ] Agent handles larger context better

**Expected**: Consistent review standards, agent provides same quality with better context capacity

## Dogfooding Validation

**First Use Date**: TBD

**PR Tested**: TBD

**Findings**:
- Agent initialization: TBD
- Review execution: TBD
- Report quality: TBD
- Context handling: TBD

**Issues Found**: TBD

**Validation Notes**: TBD
