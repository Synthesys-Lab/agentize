# Documentation Directory

This directory contains all user-facing and developer documentation for the Agentize framework.

## Organization

### User Tutorials (Sequential Learning Path)

Learn Agentize step-by-step in 15 minutes total (3-5 min per tutorial):

See [`tutorial/README.md`](tutorial/README.md) for the complete tutorial series:
- `tutorial/00-initialize.md` - Project initialization and setup
- `tutorial/01-ultra-planner.md` - Primary planning tutorial (recommended)
- `tutorial/02-issue-to-impl.md` - Complete development cycle
- `tutorial/03-advanced-usage.md` - Parallel development workflows

### CLI Reference

Command-line interface documentation for Agentize tools:
- `cli/acw.md` - `acw` agent CLI wrapper interface
- `cli/lol.md` - `lol` command interface and options
- `cli/planner.md` - `planner` multi-agent planning CLI
- `cli/wt.md` - `wt` command interface and options

### Architecture Documentation

System design and internal architecture:
- `architecture/sdk.md` - SDK generation and template system
- `architecture/metadata.md` - Metadata management and structure

### Workflows

Detailed workflow diagrams and process documentation:

See [`feat/README.md`](feat/README.md) for all workflow diagrams:
- `feat/core/milestone.md` - Milestone-based implementation workflow
- `feat/core/ultra-planner.md` - Multi-agent debate-based planning
- `feat/core/issue-to-impl.md` - Complete development cycle
- `feat/core/handsoff.md` - Handsoff mode auto-continuation

### Testing Documentation

Testing framework, validation, and agent testing:
- `test/workflow.md` - Testing framework and validation
- `test/agents.md` - Agent testing documentation
- `test/code-review-agent.md` - Code review agent testing

### Component Reference

- `agents.md` - Agent definitions and configurations
- `commands.md` - Command shortcuts and workflows
- `skills.md` - Reusable skill definitions

### Reference Documentation

- `envvar.md` - Environment variables reference
- `git-msg-tags.md` - Git commit message tag standards

## Getting Started

New to Agentize? Start with the tutorial series in order:

1. Tutorial 00: Initialize your project
2. Tutorial 01: Learn to plan features
3. Tutorial 02: Implement your first issue
4. Tutorial 03: Scale up with parallel development

## Maintenance Note

When adding or moving documentation files, update this index to keep references accurate.
