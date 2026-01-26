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
lol serve [--period=5m] [--num-workers=5]

# Direct Python invocation
python -m agentize.server --period=5m --num-workers=5
```

Telegram credentials are loaded from `.agentize.local.yaml`. The server searches for this file in: project root → `$AGENTIZE_HOME` → `$HOME`. The server runs in notification-less mode when no credentials are configured.

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
2. Checks if the resolved issue has Status = "Rebasing" (skip if already being processed)
3. Locates the corresponding worktree via `wt pathto <issue-no>`
4. Claims the issue by setting Status = "Rebasing" via `wt_claim_issue_status()`
5. Executes `wt rebase <pr-no> --headless` using the worker pool
6. Logs output to `.tmp/logs/rebase-<pr-no>-<timestamp>.log`

The status-based filtering prevents duplicate worker assignments: when `filter_conflicting_prs()` discovers a conflicting PR, it checks the resolved issue's project status. If the status is already "Rebasing" (claimed by a previous poll cycle), the PR is skipped.

If rebase fails due to conflicts:
- The rebase is aborted (`git rebase --abort`)
- The worker is marked FREE
- An error is logged with the log file path for manual review

### Debug Logging

When `handsoff.debug: true` is set in `.agentize.local.yaml`, the server logs PR discovery and filtering decisions:

```
  - PR #123: { mergeable: CONFLICTING, status: Backlog }, decision: QUEUE, reason: needs rebase
  - PR #124: { mergeable: UNKNOWN }, decision: SKIP, reason: retry next poll
  - PR #125: { mergeable: MERGEABLE }, decision: SKIP, reason: healthy
  - PR #126: { mergeable: CONFLICTING, status: Rebasing }, decision: SKIP, reason: already being rebased
[26-01-18-14:30:15] [INFO] [github.py:481:filter_conflicting_prs] Summary: 1 queued, 3 skipped (1 healthy, 1 unknown, 1 rebasing)
```

## Feature Request Planning Workflow

The server automatically discovers feature request issues and generates implementation plans using `/ultra-planner`.

### Feature Request Discovery

Issues eligible for feature request planning must have:
1. Label `agentize:dev-req`
2. NOT have label `agentize:plan` (not already planned)
3. Status NOT be `Done` or `In Progress` (terminal statuses)

The server polls for these candidates using:
```bash
gh issue list --label agentize:dev-req --state open
```

### Feature Request State Machine

When a feature request candidate is found:

1. **Discover**: Server finds issues with `agentize:dev-req` label
2. **Filter**: Server excludes issues that already have `agentize:plan` label or are in terminal status
3. **Spawn**: Server runs `/ultra-planner --from-issue <issue-no>` headlessly
4. **Cleanup**: After planning completes:
   - The `agentize:dev-req` label is removed
   - The `agentize:plan` label is added (by `/ultra-planner`)
   - Issue is ready for review/refinement

### Debug Logging (Feature Request)

When `handsoff.debug: true` is set in `.agentize.local.yaml`:

```
  - Issue #42: { labels: [agentize:dev-req], status: Backlog }, decision: READY, reason: matches criteria
  - Issue #43: { labels: [agentize:dev-req, agentize:plan], status: Proposed }, decision: SKIP, reason: already has agentize:plan
  - Issue #44: { labels: [agentize:dev-req], status: Done }, decision: SKIP, reason: terminal status
[26-01-18-14:30:15] [INFO] [github.py:657:filter_ready_feat_requests] Summary: 1 ready, 2 skipped (1 already planned, 1 terminal status)
```

### Manual Feature Request Trigger

To trigger feature request planning for an issue:
1. Add the `agentize:dev-req` label (via GitHub UI or `gh issue edit --add-label agentize:dev-req`)
2. Wait for the next server poll cycle

The label can be added via GitHub UI or CLI:
```bash
gh issue edit <issue-no> --add-label agentize:dev-req
```

### Migration Note

If you have existing issues labeled with the old `agentize:feat-request` label, you must relabel them to `agentize:dev-req` for the server to discover them. Use:
```bash
gh issue edit <issue-no> --remove-label agentize:feat-request --add-label agentize:dev-req
```

## PR Review Resolution Workflow

The server automatically discovers PRs with unresolved review threads and processes them using `/resolve-review`.

### Review Resolution Discovery

PRs eligible for review resolution must have:
1. Label `agentize:pr` (PRs created by agentize)
2. Linked issue with Status = `Proposed` (ensures work is ready for review, not actively being developed)
3. At least one review thread that is both `isResolved == false` AND `isOutdated == false`

The server polls for candidate PRs using:
```bash
gh pr list --label agentize:pr --state open --json number,headRefName,body,closingIssuesReferences
```

### Review Resolution State Machine

When a review resolution candidate is found:

1. **Discover**: Server finds PRs with `agentize:pr` label
2. **Filter**: Server checks linked issue Status == `Proposed` and calls `has_unresolved_review_threads()` via GraphQL
3. **Claim**: Server sets linked issue Status to `In Progress` (concurrency control)
4. **Spawn**: Server runs `/resolve-review <pr-no>` headlessly in the issue worktree
5. **Cleanup**: After completion, Status is reset to `Proposed` (best-effort)

### Status Lifecycle

The review resolution workflow uses the `Proposed → In Progress → Proposed` status lifecycle:

| Phase | Status | Reason |
|-------|--------|--------|
| Before claim | `Proposed` | Work is complete, awaiting review resolution |
| During resolution | `In Progress` | Prevents duplicate workers, indicates active processing |
| After completion | `Proposed` | Ready for next review cycle or PR merge |

This lifecycle uses existing Status options without requiring new statuses like "Reviewing".

### Debug Logging (Review Resolution)

When `handsoff.debug: true` is set in `.agentize.local.yaml`:

```
  - PR #123: { issue: 42, status: Proposed, threads: 3 unresolved }, decision: READY, reason: matches criteria
  - PR #124: { issue: 43, status: In Progress }, decision: SKIP, reason: status != Proposed
  - PR #125: { issue: 44, status: Proposed, threads: 0 unresolved }, decision: SKIP, reason: no unresolved threads
[26-01-22-14:30:15] [INFO] [github.py:720:filter_ready_review_prs] Summary: 1 ready, 2 skipped (1 wrong status, 1 no threads)
```

### Manual Review Resolution Trigger

To trigger review resolution for a PR:
1. Ensure the linked issue is in `Proposed` status
2. Add unresolved review comments to the PR
3. Wait for the next server poll cycle

Or manually run (from the issue branch with an open PR):
```bash
claude --print "/resolve-review"
```

### Stuck In Progress Recovery

If an issue gets stuck in `In Progress` status (e.g., after a server crash):
1. Manually reset Status to `Proposed` via GitHub Projects UI
2. The PR will be picked up on the next poll cycle

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

When `handsoff.debug: true` is set in `.agentize.local.yaml`:

```
  - Issue #42: { labels: [agentize:plan, agentize:refine], status: Proposed }, decision: READY, reason: matches criteria
  - Issue #43: { labels: [agentize:plan], status: Proposed }, decision: SKIP, reason: missing agentize:refine label
  - Issue #44: { labels: [agentize:plan, agentize:refine], status: Plan Accepted }, decision: SKIP, reason: status != Proposed
[26-01-18-14:30:15] [INFO] [github.py:386:filter_ready_refinements] Summary: 1 ready, 2 skipped (1 wrong status, 1 missing agentize:refine)
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
  org: <owner>            # Organization or personal user login
  id: <project-number>

# Optional: Explicit remote URL for issue/PR hyperlinks in Telegram notifications
# If omitted, automatically resolved from `git remote get-url origin`
# git:
#   remote_url: https://github.com/org/repo
```

### Runtime Configuration

For server-specific settings that shouldn't be committed (credentials, worker pool size, model preferences), use `.agentize.local.yaml`:

```yaml
# .agentize.local.yaml - Runtime configuration (git-ignored)
handsoff:
  enabled: true
  max_continuations: 10
  auto_permission: true
  debug: false
  supervisor:
    provider: claude
    model: opus

server:
  period: 5m
  num_workers: 5

telegram:
  enabled: true
  token: "your-bot-token"
  chat_id: "your-chat-id"
  timeout_sec: 60
  poll_interval_sec: 5

workflows:
  impl:
    model: opus
  refine:
    model: sonnet
  dev_req:
    model: sonnet
  rebase:
    model: haiku
```

**Configuration precedence:** CLI args > `.agentize.local.yaml` > defaults

For example:
- `lol serve --period=10m` uses `10m` regardless of YAML config
- `lol serve` without args uses YAML `server.period: 2m` if configured
- If neither CLI nor YAML specifies a value, defaults are used (`5m` for period, `5` for workers)

**Sections:**
- `handsoff`: Handsoff mode settings for auto-continuation (see [Handsoff Mode](core/handsoff.md))
- `server`: Polling period and worker pool size
- `telegram`: Bot token, chat ID, and approval settings (see [Telegram Approval](permissions/telegram.md))
- `workflows`: Per-workflow Claude model selection (opus, sonnet, haiku)

**YAML search order:**
1. Project root `.agentize.local.yaml`
2. `$AGENTIZE_HOME/.agentize.local.yaml`
3. `$HOME/.agentize.local.yaml` (user-wide, created by installer)

For the complete configuration schema, see [Configuration Reference](../envvar.md).

**Note:** This file should NOT be committed. It is automatically git-ignored.

### Remote URL Configuration

The `git.remote_url` field enables clickable hyperlinks for issue and PR numbers in Telegram notifications. This field is **optional** - when not configured, the server automatically resolves the URL from `git remote get-url origin`.

**Supported URL formats:**
- HTTPS: `https://github.com/org/repo` or `https://github.com/org/repo.git`
- SSH: `git@github.com:org/repo.git`

**Fallback behavior:**
1. Server checks for `git.remote_url` in `.agentize.yaml`
2. If not found, runs `git remote get-url origin` to resolve automatically
3. If both fail, notifications display plain text issue numbers (graceful degradation)

## Troubleshooting

### Issue Discovery Errors

If `gh issue list` fails (e.g., network error, auth issue), the server returns an empty candidate list without crashing, and logs the error for investigation.

### Per-Issue Status Lookup Errors

Error messages include source location (file:line:function) for quick debugging:

```
[26-01-09-12:30:47] [ERROR] [__main__.py:163:query_issue_project_status] GraphQL query failed: ...
```

For additional context (query and variables), set `handsoff.debug: true` in `.agentize.local.yaml`:

```yaml
handsoff:
  debug: true
```

This logs the GraphQL query and variables on failures, helping diagnose variable type mismatches or query syntax issues.

### Issue Filtering Debug Logs

When issues aren't being picked up by the server, enable debug logging to see filtering decisions by setting `handsoff.debug: true` in `.agentize.local.yaml`.

Debug output shows per-issue inspection with status, labels, and rejection reasons:

```
  - Issue #42: { labels: [agentize:plan, bug], status: Plan Accepted }, decision: READY, reason: matches criteria
  - Issue #43: { labels: [enhancement], status: Backlog }, decision: SKIP, reason: status != Plan Accepted
  - Issue #44: { labels: [feature], status: Plan Accepted }, decision: SKIP, reason: missing agentize:plan label
[26-01-18-14:30:15] [INFO] [github.py:330:filter_ready_issues] Summary: 1 ready, 2 skipped (1 wrong status, 1 missing label)
```

Each individual scan line includes:
- Issue number with 2-space indentation
- Structured format with labels and status
- Decision (READY or SKIP) and reason
- Summary line with timestamp and source location

## Telegram Notifications

When Telegram credentials are configured in `.agentize.local.yaml`, the server sends notifications:

### Startup Notification

Sent when the server starts, including hostname, project identifier, polling period, and working directory.

### Worker Assignment Notification

Sent when an issue is successfully assigned to a worker, including:
- Issue number and title (clickable hyperlink to GitHub issue)
- Worker ID

The issue link is automatically resolved from `git remote get-url origin`. If explicit configuration is needed, set `git.remote_url` in `.agentize.yaml`. If the URL cannot be resolved, the notification displays the issue number as plain text without error.

### Worker Completion Notification

Sent when a worker PID is found dead and the associated session's state is `done`, indicating successful completion:
- Issue number (clickable hyperlink to GitHub issue)
- Worker ID
- GitHub PR link (clickable hyperlink when `pr_number` is recorded in session state)

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
