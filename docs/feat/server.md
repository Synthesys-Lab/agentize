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

### Issue Filtering Debug Logs

When issues aren't being picked up by the server, enable debug logging to see filtering decisions:

```bash
HANDSOFF_DEBUG=1 lol serve --tg-token=<token> --tg-chat-id=<id>
```

Debug output shows per-issue inspection with status, labels, and rejection reasons:

```
[issue-filter] #42 status=Plan Accepted labels=[agentize:plan, bug] -> READY
[issue-filter] #43 status=Backlog labels=[enhancement] -> SKIP (status != Plan Accepted)
[issue-filter] #44 status=Plan Accepted labels=[feature] -> SKIP (missing agentize:plan label)
[issue-filter] Summary: 1 ready, 2 skipped (1 wrong status, 1 missing label)
```

Each line includes:
- Issue number
- Current status value
- Label list
- Decision (READY or SKIP with reason)
