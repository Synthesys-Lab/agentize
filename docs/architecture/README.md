# Architecture Documentation

This directory contains documentation about the internal architecture and design of Agentize.

## Purpose

These documents explain how Agentize's core systems work, their design decisions, and implementation details. They serve as reference material for understanding the codebase structure and extending the framework.

## Files

### sdk.md
SDK structure documentation. Describes the file structure of SDK projects using the Agentize framework, the `.claude/` directory organization, and setup workflows.

### metadata.md
Project metadata file (`.agentize.yaml`) specification. Describes the configuration schema, field definitions, usage by `wt` and `lol` commands, and how metadata drives project behavior.

### handsoff.md
Handsoff mode documentation. Describes the automatic continuation mechanism for workflows, environment variables (`HANDSOFF_MODE`, `HANDSOFF_AUTO_PERMISSION`), and supported workflows (`ultra-planner`, `issue-to-impl`, `plan-to-issue`).

## Integration

Architecture documentation is referenced from:
- Main [README.md](../README.md) under "Architecture Documentation"
- Tutorial series in [docs/tutorial/](../tutorial/)
- Command implementations that depend on these systems

## Usage

These documents are primarily for:
- Contributors understanding the codebase
- Users extending Agentize with custom templates or integrations
- Developers debugging SDK initialization or metadata issues
