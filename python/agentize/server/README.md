# Agentize Server Module

Polling server for GitHub Projects v2 automation.

## Purpose

This module implements a long-running server that:
1. Polls GitHub Projects v2 at configurable intervals
2. Identifies issues with "Plan Accepted" status and `agentize:plan` label
3. Spawns worktrees for implementation via `wt spawn`

## Files

- `__init__.py` - Module exports
- `__main__.py` - Main polling loop and CLI entry point

## Usage

```bash
# Via lol CLI (recommended)
lol serve --tg-token=<token> --tg-chat-id=<id> --period=5m

# Direct Python invocation
python -m agentize.server --period=5m
```

## Configuration

Reads project association from `.agentize.yaml`:
```yaml
project:
  org: <organization>
  id: <project-number>
```
