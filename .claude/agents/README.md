# Agents

This directory contains agent definitions for Claude Code. Agents are specialized AI assistants for complex tasks requiring isolated context and specific model configurations.

## Purpose

Agents provide isolated execution environments for complex, multi-step tasks. Each agent is defined as a markdown file with YAML frontmatter configuration.

## Organization

- Each agent is a `.md` file in the `agents/` directory
- Agent files include:
  - YAML frontmatter: Configuration (name, description, model, tools, skills)
  - Markdown content: Agent behavior specification and workflow

## Available Agents

### Review & Analysis

- `code-quality-reviewer.md`: Comprehensive code review with enhanced quality standards using Opus model for long context analysis

### Debate-Based Planning

Multi-perspective planning agents for collaborative proposal development:

- `bold-proposer.md`: Research SOTA solutions and propose innovative, bold approaches
- `proposal-critique.md`: Validate assumptions and analyze technical feasibility
- `proposal-reducer.md`: Simplify proposals following "less is more" philosophy

These agents work together in the `/ultra-planner` workflow to generate well-balanced implementation plans through structured debate.
