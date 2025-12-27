# Workflow Diagrams

This folder contains visual workflow diagrams that illustrate Agentize's automated development processes.

## Purpose

These diagrams provide detailed visualizations of how Agentize commands orchestrate multi-agent planning and implementation workflows. They complement the main README by offering deeper insight into the automation architecture.

## Files

### ultra-planner.md
Multi-agent debate-based planning workflow showing how the `/ultra-planner` command coordinates three specialized agents (bold-proposer, critique, reducer) with external consensus review to generate comprehensive implementation plans.

### issue-to-implementation.md
Complete development cycle workflow showing how the `/issue-to-impl` command automates the journey from GitHub issue to pull request, including documentation, testing, milestone tracking, and code review phases.

## Integration

These workflows are referenced from the main [README.md](../../README.md) and correspond to:
- Tutorial sections in [docs/tutorial/](../tutorial/)
- Command implementations in [.claude/commands/](.claude/commands/)
- Skills in [.claude/skills/](.claude/skills/)

The legend convention (red boxes = user interventions, blue boxes = automated steps) applies to all workflow diagrams.
