# Agentize Server

Polling server for GitHub Projects v2 automation.

## Overview

A long-running server that monitors your GitHub Projects kanban board and automatically executes approved plans:

1. Polls GitHub Projects v2 at configurable intervals
2. Identifies issues with "Plan Accepted" status and `agentize:plan` label
3. Spawns worktrees for implementation via `wt spawn`

## Usage

```bash
# Via lol CLI (recommended)
lol serve --tg-token=<token> --tg-chat-id=<id> --period=5m

# Direct Python invocation
python -m agentize.server --period=5m
```

## Configuration

The server reads project association from `.agentize.yaml` in your repository root:

```yaml
project:
  org: <organization>
  id: <project-number>
```

## Troubleshooting

### GraphQL Errors

Error messages include source location (file:line:function) for quick debugging:

```
[2026-01-09T12:30:47] [ERROR] [__main__.py:163:query_project_items] GraphQL query failed: ...
```

For additional context (query and variables), set `HANDSOFF_DEBUG=1`:

```bash
HANDSOFF_DEBUG=1 lol serve --tg-token=<token> --tg-chat-id=<id>
```

This logs the GraphQL query and variables on failures, helping diagnose variable type mismatches or query syntax issues.
