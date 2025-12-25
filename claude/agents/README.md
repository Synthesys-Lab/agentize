# Agents

This directory contains agent definitions for Claude Code. Agents are specialized AI assistants for complex tasks requiring isolated context and specific model configurations.

## Purpose

Agents provide isolated execution environments for complex, multi-step tasks. Each agent is defined with a specification file (AGENT.md), configuration (agent.json), and documentation (README.md).

## Organization

- Each agent is in its own subdirectory
- Agent directories include:
  - `AGENT.md`: Agent behavior specification and workflow
  - `agent.json`: Configuration (model, tools, skills, timeout)
  - `README.md`: User-facing documentation and usage examples

## Available Agents

- `code-review/`: Comprehensive code review with enhanced quality standards using Opus model for long context analysis
