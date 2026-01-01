# Testing Documentation

This directory contains documentation about testing strategies, validation workflows, and agent testing for Agentize.

## Purpose

These documents track testing status, define test strategies, and document validation approaches for AI-powered components. Since AI rules are subjective and LLM-dependent, this documentation emphasizes dogfooding (using Agentize to develop itself) as the primary validation method.

## Files

### workflow.md
Testing and dogfooding status tracker. Documents the validation status of all skills, commands, and agents, with real-world usage examples and maturity indicators (✅ Validated, 🔄 In Progress, ⚠️ Partial, ❌ Untested, 🔧 Needs Revision).

### agents.md
Agent infrastructure test coverage. Defines test cases for the `.claude/agents/` directory, agent discovery, directory structure validation, and dogfooding validation criteria.

### code-review-agent.md
Code review agent test coverage. Documents test cases for the code-review agent functionality, review standards enforcement, and integration with the review workflow.

## Testing Philosophy

Agentize follows a **dogfooding-first** testing approach:
- AI rules are tested by using them to develop Agentize itself
- Real-world usage provides the most realistic validation
- Traditional unit tests complement but don't replace dogfooding
- Validation status is tracked and documented for transparency

## Integration

Testing documentation is referenced from:
- Main [README.md](../README.md) under "Testing Documentation"
- Workflows in [docs/workflows/](../workflows/)
- Individual skill and command implementations
