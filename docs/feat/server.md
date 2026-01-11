# Agentize Server

Polling server for GitHub Projects v2 automation.

## Overview

A long-running server that monitors your GitHub Projects kanban board and automatically executes approved plans and refinement requests:

1. Discovers candidate issues using `gh issue list --label agentize:plan --state open`
2. Checks per-issue project status via GraphQL to enforce the "Plan Accepted" approval gate (for implementation) or detect "Proposed" + `agentize:refine` label (for refinement)
3. Spawns worktrees for ready issues via `wt spawn` or triggers refinement via `/ultra-planner --refine`
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

## PR Auto-Rebase Workflow

The server automatically detects PRs with merge conflicts and rebases their corresponding worktrees.

### PR Discovery

PRs created by agentize are labeled with `agentize:pr`. The server periodically scans for these PRs:

```bash
gh pr list --label agentize:pr --state open --json number,headRefName,mergeable
```

### Mergeable State Handling

GitHub's `mergeable` field has three possible values:

| Value | Meaning | Server Action |
|-------|---------|---------------|
| `MERGEABLE` | No conflicts | Skip (healthy) |
| `CONFLICTING` | Has conflicts | Queue rebase |
| `UNKNOWN` | Still computing | Skip and retry next poll |

The `UNKNOWN` state occurs when GitHub is computing merge status. The server skips these PRs to avoid flapping and retries on the next poll cycle.

### Rebase Dispatch

When a PR with `mergeable=CONFLICTING` is detected, the server:

1. Resolves the issue number from PR metadata
2. Locates the corresponding worktree via `wt pathto <issue-no>`
3. Executes `wt rebase <pr-no> --headless` using the worker pool
4. Logs output to `.tmp/logs/rebase-<pr-no>-<timestamp>.log`

If rebase fails due to conflicts:
- The rebase is aborted (`git rebase --abort`)
- The worker is marked FREE
- An error is logged with the log file path for manual review

### Debug Logging

When `HANDSOFF_DEBUG=1` is set, the server logs PR discovery and filtering decisions:

```
[pr-rebase] #123 mergeable=CONFLICTING -> QUEUE
[pr-rebase] #124 mergeable=UNKNOWN -> SKIP (retry next poll)
[pr-rebase] #125 mergeable=MERGEABLE -> SKIP (healthy)
```

## Feature Request Planning Workflow

The server automatically discovers feature request issues and generates implementation plans using `/ultra-planner`.

### Feature Request Discovery

Issues eligible for feature request planning must have:
1. Label `agentize:feat-request`
2. NOT have label `agentize:plan` (not already planned)
3. Status NOT be `Done` or `In Progress` (terminal statuses)

The server polls for these candidates using:
```bash
gh issue list --label agentize:feat-request --state open
```

### Feature Request State Machine

When a feature request candidate is found:

1. **Discover**: Server finds issues with `agentize:feat-request` label
2. **Filter**: Server excludes issues that already have `agentize:plan` label or are in terminal status
3. **Spawn**: Server runs `/ultra-planner --from-issue <issue-no>` headlessly
4. **Cleanup**: After planning completes:
   - The `agentize:feat-request` label is removed
   - The `agentize:plan` label is added (by `/ultra-planner`)
   - Issue is ready for review/refinement

### Debug Logging (Feature Request)

When `HANDSOFF_DEBUG=1` is set:

```
[feat-request-filter] #42 labels=[agentize:feat-request] status=Backlog -> READY
[feat-request-filter] #43 labels=[agentize:feat-request, agentize:plan] -> SKIP (already has agentize:plan)
[feat-request-filter] #44 labels=[agentize:feat-request] status=Done -> SKIP (terminal status)
```

### Manual Feature Request Trigger

To trigger feature request planning for an issue:
1. Add the `agentize:feat-request` label (via GitHub UI or `gh issue edit --add-label agentize:feat-request`)
2. Wait for the next server poll cycle

The label can be added via GitHub UI or CLI:
```bash
gh issue edit <issue-no> --add-label agentize:feat-request
```

## Plan Refinement Workflow

The server automatically discovers and processes plan refinement candidates.

### Refinement Discovery

Issues eligible for refinement must have:
1. Status = `Proposed`
2. Labels include both `agentize:plan` and `agentize:refine`

The server polls for these candidates using:
```bash
gh issue list --label agentize:plan,agentize:refine --state open
```

### Refinement State Machine

When a refinement candidate is found:

1. **Claim**: Server sets Status to `Refining` (best-effort concurrency control)
2. **Spawn**: Server creates a worktree and runs `/ultra-planner --refine` headlessly
3. **Cleanup**: After refinement completes:
   - Status returns to `Proposed`
   - The `agentize:refine` label is removed

### Debug Logging (Refinement)

When `HANDSOFF_DEBUG=1` is set:

```
[refine-filter] #42 status=Proposed labels=[agentize:plan, agentize:refine] -> READY
[refine-filter] #43 status=Proposed labels=[agentize:plan] -> SKIP (missing agentize:refine label)
[refine-filter] #44 status=Plan Accepted labels=[agentize:plan, agentize:refine] -> SKIP (status != Proposed)
```

### Manual Refinement Trigger

To trigger refinement for an issue:
1. Ensure the issue is in `Proposed` status
2. Add the `agentize:refine` label
3. Wait for the next server poll cycle

The label can be added via GitHub UI or CLI:
```bash
gh issue edit <issue-no> --add-label agentize:refine
```

### Stuck Refining Recovery

If an issue gets stuck in `Refining` status (e.g., after a server crash):
1. Manually reset Status to `Proposed` via GitHub Projects UI
2. Optionally re-add `agentize:refine` label to retry

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
[26-01-09-12:30:47] [ERROR] [__main__.py:163:query_issue_project_status] GraphQL query failed: ...
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

### Worker Completion Notification

Sent when a worker PID is found dead and the associated session's state is `done`, indicating successful completion:
- Issue number
- Worker ID
- GitHub issue link (when available)

**Requirements for completion notification:**
1. Worker PID must be dead (process exited)
2. Session state file must exist at `${AGENTIZE_HOME:-.}/.tmp/hooked-sessions/{session_id}.json`
3. Session state must be `done`
4. Issue index file must exist at `${AGENTIZE_HOME:-.}/.tmp/hooked-sessions/by-issue/{issue_no}.json`

**Deduplication:** After a successful completion notification, the issue index file is removed to prevent duplicate notifications across server restart cycles.

**Failure cases (no notification sent):**
- Session state is not `done` (e.g., `initial`, `in_progress`)
- Issue index file is missing (workflow not invoked with issue number)
- Telegram credentials are not configured

## Implementation Layout (Internal)

The server is organized into focused modules for maintainability:

```
python/agentize/server/
├── __main__.py    # CLI entry point and polling coordinator
├── github.py      # GitHub issue/PR discovery and GraphQL helpers
├── workers.py     # Worktree spawn/rebase and worker status files
├── notify.py      # Telegram message formatting and sending
├── session.py     # Session state file lookups
├── log.py         # Shared logging helper
└── README.md      # Module layout and re-export policy
```

All public functions are re-exported from `__main__.py` to preserve backward compatibility with existing test imports (e.g., `from agentize.server.__main__ import read_worker_status`).
