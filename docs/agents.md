# Agents

This document describes the agent definitions for Claude Code. Agents are specialized AI assistants for complex tasks requiring isolated context and specific model configurations.

## Purpose

Agents provide isolated execution environments for complex, multi-step tasks. Each agent is defined as a markdown file with YAML frontmatter configuration in the `agents/` directory.

## Configuration

Agent files include:
- YAML frontmatter: Configuration (name, description, model, tools, skills)
- Markdown content: Agent behavior specification and workflow

## Available Agents

### Review & Analysis

- `code-quality-reviewer`: Comprehensive code review with enhanced quality standards using Opus model for long context analysis

### Debate-Based Planning

Multi-perspective planning agents for collaborative proposal development:

- `understander`: Gather codebase context and estimate complexity (feeds routing decision)
- `planner-lite`: Lightweight single-agent planner for simple modifications (<5 files, <150 LOC, repo-only)
- `bold-proposer`: Research SOTA solutions and propose innovative, bold approaches
- `proposal-critique`: Validate assumptions and analyze technical feasibility
- `proposal-reducer`: Simplify proposals following "less is more" philosophy

These agents work together in the `/ultra-planner` workflow:
1. Understander runs first to gather context and check lite conditions
2. If lite (repo-only, <5 files, <150 LOC): Planner-lite creates plan directly
3. If full (needs research or complex): Bold-proposer + Critique + Reducer debate
4. External consensus synthesizes final plan (full path only)

**Plugin mode invocation:** When Agentize is installed as a Claude Code plugin, agents are namespaced with the `agentize:` prefix (e.g., `agentize:understander`, `agentize:bold-proposer`). Commands and skills within this plugin should use the prefixed names for Task tool invocations.
