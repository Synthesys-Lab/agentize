# Project Board Integration Rule

## Core Requirement

**Every GitHub issue created by Claude Code workflows MUST be added to the GitHub Project board.**

**CRITICAL CONSTRAINT**: Only issues can be added to GitHub Projects - **NOT pull requests**.

**Scope**: This requirement applies to ALL issues created by Claude Code workflows and agents, regardless of issue type:
- Implementation issues (with file changes)
- Documentation issues (may have no code changes)
- Handoff issues (continuation points)
- Sub-issues (part of larger features)

**Note**: This rule does NOT apply to issues created manually outside of Claude Code workflows.

This rule applies to ALL Claude Code issue-creating operations:
- `/feat2issue` command
- `/issue2impl` command (via `handoff-generator`)
- `/gen-handoff` command
- Any agent that creates GitHub issues

**Why only issues?** GitHub Projects track implementation work (issues), not code review state (PRs). PRs are linked to issues via "Resolves #XXX" in the PR description, which automatically updates the issue status when the PR is merged.

## Architectural Constraint

**Subagents CANNOT spawn other subagents.** This is a Claude Code architectural constraint.

### Correct Pattern

```
Command/Main Thread
    ├── spawns → issue-creating agent (e.g., issue-creator, handoff-generator)
    │   └── returns → issue numbers and metadata
    └── spawns → project-manager agent (with extracted issue numbers)
```

### Incorrect Pattern (Will Not Work)

```
Command/Main Thread
    └── spawns → issue-creating agent
        └── spawns → project-manager  ← IMPOSSIBLE: subagents cannot spawn subagents
```

## Integration Points

### For Issue-Creating Agents

Agents that create issues (e.g., `issue-creator`, `handoff-generator`) must:

1. **Create the issue** using `gh issue create`
2. **Return structured output** with issue details:

```
### Project Board Integration Required

The calling context MUST spawn `project-manager` agent with:
- Issue number: #<number>
- L1 Component: <value>
- L2 Subcomponent: <value> (if applicable)
- Priority: <value>
- Effort: <value>
```

3. **NOT attempt to spawn project-manager** (impossible for subagents)

### For Commands

Commands (e.g., `/gen-handoff`, `/issue2impl`, `/feat2issue`) must:

1. **Spawn issue-creating agent** if needed
2. **Parse agent output** to extract issue numbers and metadata
3. **Verify the output contains ISSUE numbers** (not PR numbers) before spawning project-manager
4. **Spawn `project-manager` agent** for EACH issue created:

```
Add issue #<issue-number> to GitHub Project.

Context:
- Issue number: <from agent output>
- L1 Component: <from agent output>
- L2 Subcomponent: <from agent output, if applicable>
- Priority: <from agent output>
- Effort: <from agent output>

Add to appropriate project and update fields.
```

5. **Handle permission errors gracefully**:
   - Inform user about the error
   - Suggest: `gh auth refresh -s project`
   - Provide manual fallback link

## Workflow-Specific Integration

### /feat2issue

| Phase | Issue Created | project-manager Required |
|-------|---------------|--------------------------|
| 5.1.1 | Documentation issue | Yes (Phase 5.1.1a) |
| 5.2 | Implementation issues | Yes (Phase 5.3, for each) |

### /issue2impl

| Phase | Issue Created | project-manager Required |
|-------|---------------|--------------------------|
| 5.4.1 | Handoff issue | Yes (Phase 5.4.2) |

### /gen-handoff

| Step | Issue Created | project-manager Required |
|------|---------------|--------------------------|
| Step 6 | Handoff issue | Yes (Step 7) |

## Error Handling

If `project-manager` reports a permission error:

1. **Display to user**:
   ```
   Issue #<number> created but could not be added to GitHub Project automatically.
   ```

2. **Suggest fix**:
   ```
   Run `gh auth refresh -s project` to add project permissions, then retry.
   ```

3. **Provide manual fallback**:
   ```
   Or add manually at: https://github.com/orgs/PolyArch/projects
   ```

4. **Continue execution** - don't block the workflow due to project board issues

## Validation Checklist

When reviewing or creating issue-creating workflows:

- [ ] Does every issue creation have a corresponding `project-manager` spawn?
- [ ] Is `project-manager` spawned by the command/main thread (not by a subagent)?
- [ ] Are ONLY issue numbers (not PR numbers) passed to `project-manager`?
- [ ] Is the issue metadata correctly passed to `project-manager`?
- [ ] Is error handling included for permission issues?
- [ ] Is the project board step marked as MANDATORY?

## Related Files

| File | Role |
|------|------|
| `.claude/agents/project-manager.md` | Agent definition |
| `.claude/agents/handoff-generator.md` | Returns issue details for project-manager |
| `.claude/agents/issue-creator.md` | Returns issue list for project-manager |
| `.claude/commands/issue2impl.md` | Phase 5.4.2 spawns project-manager |
| `.claude/commands/gen-handoff.md` | Step 7 spawns project-manager |
| `.claude/commands/feat2issue.md` | Phase 5.1.1a and 5.3 spawn project-manager |
