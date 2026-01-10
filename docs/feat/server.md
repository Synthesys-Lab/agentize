# Agentize Server

Polling server for GitHub Projects v2 automation.

## Overview

A long-running server that monitors your GitHub Projects kanban board and automatically executes approved plans:

1. Discovers candidate issues using `gh issue list --label agentize:plan --state open`
2. Checks per-issue project status via GraphQL to enforce the "Plan Accepted" approval gate
3. Spawns worktrees for ready issues via `wt spawn`
4. Manages concurrent workers with bounded concurrency (default: 5 workers)

## Usage

```bash
# Via lol CLI (recommended)
lol serve --tg-token=<token> --tg-chat-id=<id> --period=5m --num-workers=5

# Direct Python invocation
python -m agentize.server --period=5m --num-workers=5
```

## Worker Pool

The server manages a pool of concurrent workers to process multiple issues simultaneously while respecting resource limits.

### Concurrency Control

- `--num-workers=N`: Maximum concurrent headless Claude sessions (default: 5)
- `--num-workers=0`: No limit (preserves prior behavior)

### Worker Status Files

Worker state is tracked in `.tmp/workers/` with one status file per worker slot:

```
.tmp/workers/
├── worker-0.status
├── worker-1.status
├── worker-2.status
├── worker-3.status
└── worker-4.status
```

**File format (key=value per line):**

When free:
```
state=FREE
```

When busy:
```
state=BUSY
issue=42
pid=12345
```

### Worker Assignment

When an issue is assigned to a worker:
```
issue #42 is assigned to worker 0
```

### Headless Spawn Output Parsing

The server parses `wt spawn --headless` output to extract the worker PID. The expected output format is:
```
PID: 12345
Log: .tmp/logs/issue-42-20260110-143022.log
```

The server first looks for explicit `PID:` lines, then falls back to regex matching `PID[:\s]+(\d+)` for backward compatibility.

### Crash Recovery

On startup, the server reads existing status files and checks PID liveness. Workers with dead PIDs are automatically marked as FREE, enabling recovery after unexpected shutdowns.

## Configuration

The server reads project association from `.agentize.yaml` in your repository root:

```yaml
project:
  org: <organization>
  id: <project-number>
```

## Troubleshooting

### Issue Discovery Errors

If `gh issue list` fails (e.g., network error, auth issue), the server returns an empty candidate list without crashing, and logs the error for investigation.

### Per-Issue Status Lookup Errors

Error messages include source location (file:line:function) for quick debugging:

```
[2026-01-09T12:30:47] [ERROR] [__main__.py:163:query_issue_project_status] GraphQL query failed: ...
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

## Telegram Notifications

When Telegram credentials are configured (`TG_API_TOKEN` and `TG_CHAT_ID` via environment variables or CLI flags), the server sends notifications:

### Startup Notification

Sent when the server starts, including hostname, project identifier, polling period, and working directory.

### Worker Assignment Notification

Sent when an issue is successfully assigned to a worker, including:
- Issue number and title
- Worker ID
- GitHub issue link (when `git.remote_url` is configured in `.agentize.yaml`)

The issue link is derived from `git.remote_url` in `.agentize.yaml`. If the URL cannot be parsed or is not configured, the notification omits the link without error.
