# Server Module Interface

## External Interface

Functions exported via `__init__.py`:

### `run_server(period: int, tg_token: str | None = None, tg_chat_id: str | None = None, num_workers: int = 5) -> None`

Main polling loop that monitors GitHub Projects for ready issues.

**Parameters:**
- `period`: Polling interval in seconds
- `tg_token`: Telegram Bot API token (optional, falls back to `TG_API_TOKEN` env)
- `tg_chat_id`: Telegram chat ID (optional, falls back to `TG_CHAT_ID` env)
- `num_workers`: Maximum concurrent workers (default: 5, 0 = unlimited)

**Behavior:**
- Loads config from `.agentize.yaml`
- Sends startup notification if Telegram configured
- Polls project items at `period` intervals
- Spawns worktrees for issues with "Plan Accepted" status and `agentize:plan` label
- Sends worker assignment notification if Telegram configured
- Handles SIGINT/SIGTERM for graceful shutdown

### `send_telegram_message(token: str, chat_id: str, text: str) -> bool`

Send a message to Telegram.

**Parameters:**
- `token`: Telegram Bot API token
- `chat_id`: Chat ID to send to
- `text`: Message text (supports HTML parse mode)

**Returns:** `True` if successful, `False` otherwise

### `notify_server_start(token: str, chat_id: str, org: str, project_id: int, period: int) -> None`

Send server startup notification to Telegram with hostname, project info, and working directory.

## Internal Helpers

### `_log(msg: str, level: str = "INFO") -> None`

Log with timestamp and source location (file:line:function).

### `parse_period(period_str: str) -> int`

Parse period string (e.g., "5m", "300s") to seconds.

### `load_config() -> tuple[str, int, str | None]`

Load project org, ID, and optional remote URL from `.agentize.yaml`.

Returns: `(org, project_id, remote_url)` tuple.

**Remote URL resolution order:**
1. `git.remote_url` from `.agentize.yaml` (if explicitly configured)
2. Automatic fallback to `git remote get-url origin`
3. `None` if both fail (graceful degradation)

### `get_repo_owner_name() -> tuple[str, str]`

Resolve repository owner and name from git remote origin. Returns `(owner, repo)` tuple.

### `lookup_project_graphql_id(org: str, project_number: int) -> str`

Convert organization and project number into ProjectV2 GraphQL ID. Result is cached to avoid repeated lookups.

### `discover_candidate_issues(owner: str, repo: str) -> list[int]`

Discover open issues with `agentize:plan` label using `gh issue list`. Returns list of issue numbers.

### `query_issue_project_status(owner: str, repo: str, issue_no: int, project_id: str) -> str`

Fetch an issue's Status field value for the configured project via GraphQL. Returns the status string (e.g., "Plan Accepted") or empty string if not found.

### `query_project_items(org: str, project_number: int) -> list[dict]`

Query GitHub Projects v2 for items. Uses label-first discovery via `gh issue list` followed by per-issue status lookups via GraphQL. Returns list of items with status and labels attached.

### `filter_ready_issues(items: list[dict]) -> list[int]`

Filter items to issues with "Plan Accepted" status and `agentize:plan` label.
When `HANDSOFF_DEBUG=1`, logs per-issue inspection with status, labels, and rejection reasons.

### `filter_ready_refinements(items: list[dict]) -> list[int]`

Filter items to issues eligible for refinement: Status "Proposed" + labels include both `agentize:plan` and `agentize:refine`.
When `HANDSOFF_DEBUG=1`, logs per-issue inspection with `[refine-filter]` prefix.

### `query_refinement_items(org: str, project_number: int, owner: str, repo: str) -> list[dict]`

Query refinement candidates with label-first discovery. Discovers issues with both `agentize:plan` and `agentize:refine` labels, then queries per-issue project status via GraphQL.

### `discover_refinement_candidates(owner: str, repo: str) -> list[dict]`

Discover open issues with both `agentize:plan` and `agentize:refine` labels using `gh issue list`. Returns list of issue metadata dicts with number and labels.

### `spawn_refinement(issue_no: int) -> tuple[bool, int | None]`

Spawn a refinement session for the given issue.

**Operations:**
1. Creates worktree via `wt spawn --no-agent --headless` (if not exists)
2. Sets issue status to "Refining" via `wt_claim_issue_status()` (best-effort claim)
3. Runs `claude --print /ultra-planner --refine <issue-no>` headlessly as background process
4. Returns (success, pid) tuple

**Returns:** Tuple of (success, pid). pid is None if spawn failed.

### `_check_issue_has_label(issue_no: int, label: str) -> bool`

Check if an issue has a specific label via `gh issue view`.

**Parameters:**
- `issue_no`: GitHub issue number
- `label`: Label name to check for

**Returns:** `True` if the issue has the label, `False` otherwise.

### `_cleanup_refinement(issue_no: int) -> None`

Clean up after refinement completion: remove `agentize:refine` label.

**Operations:**
1. Remove `agentize:refine` label via `gh issue edit`
2. Log cleanup action

### `discover_candidate_feat_requests(owner: str, repo: str) -> list[int]`

Discover open issues with `agentize:dev-req` label using `gh issue list`. Returns list of issue numbers.

### `query_feat_request_items(org: str, project_number: int) -> list[dict]`

Query feat-request candidates with label-first discovery. Discovers issues with `agentize:dev-req` label, then queries per-issue project status and full label list via GraphQL.

### `filter_ready_feat_requests(items: list[dict]) -> list[int]`

Filter items to issues eligible for feat-request planning:
- Has `agentize:dev-req` label
- Does NOT have `agentize:plan` label (not already planned)
- Status is NOT "Done" or "In Progress" (terminal statuses)

When `HANDSOFF_DEBUG=1`, logs per-issue inspection with `[dev-req-filter]` prefix.

### `spawn_feat_request(issue_no: int) -> tuple[bool, int | None]`

Spawn a feat-request planning session for the given issue.

**Operations:**
1. Creates worktree via `wt spawn --no-agent --headless` (if not exists)
2. Runs `claude --print /ultra-planner --from-issue <issue-no>` headlessly as background process
3. Returns (success, pid) tuple

**Returns:** Tuple of (success, pid). pid is None if spawn failed.

### `_cleanup_feat_request(issue_no: int) -> None`

Clean up after feat-request planning completion: remove `agentize:dev-req` label.

**Operations:**
1. Remove `agentize:dev-req` label via `gh issue edit`
2. Log cleanup action

### `worktree_exists(issue_no: int) -> bool`

Check if a worktree exists for the given issue number.

### `spawn_worktree(issue_no: int) -> tuple[bool, int | None]`

Spawn a new worktree for the given issue via `wt spawn`.

**Returns:** Tuple of (success, pid). pid is None if spawn failed.

Note: Uses `run_shell_function()` from `agentize.shell` for shell invocation.

### `discover_candidate_prs(owner: str, repo: str) -> list[dict]`

Discover open PRs with `agentize:pr` label using `gh pr list`.

**Returns:** List of PR metadata dicts with `number`, `headRefName`, `mergeable`, `body`, and `closingIssuesReferences` fields.

### `filter_conflicting_prs(prs: list[dict], owner: str, repo: str, project_id: str) -> list[int]`

Filter PRs to those with merge conflicts and not already being rebased.

**Parameters:**
- `prs`: List of PR metadata dicts from `discover_candidate_prs()`
- `owner`: Repository owner
- `repo`: Repository name
- `project_id`: Project GraphQL ID for status lookup

**Filtering logic:**
- Skips `mergeable == "UNKNOWN"` (retry on next poll)
- Skips `mergeable != "CONFLICTING"` (healthy)
- Skips if resolved issue has `Status == "Rebasing"` (already being processed)
- Queues unresolvable PRs (best-effort - cannot check status without issue number)

When `HANDSOFF_DEBUG=1`, logs per-PR inspection with `[pr-rebase-filter]` prefix.

**Returns:** List of PR numbers that need rebasing.

### `resolve_issue_from_pr(pr: dict) -> int | None`

Resolve issue number from PR metadata.

**Fallback order:**
1. Branch name pattern: `issue-<N>`
2. `closingIssuesReferences` (first entry)
3. PR body `#<N>` pattern

**Returns:** Issue number or None if no match found.

### `rebase_worktree(pr_no: int, issue_no: int | None = None) -> tuple[bool, int | None]`

Rebase a PR's worktree using `wt rebase` command.

**Parameters:**
- `pr_no`: GitHub pull request number
- `issue_no`: GitHub issue number (optional, for status claim)

**Operations:**
1. Sets issue status to "Rebasing" via `wt_claim_issue_status()` if `issue_no` provided (best-effort claim)
2. Runs `wt rebase <pr_no> --headless`
3. Returns (success, pid) tuple

**Returns:** Tuple of (success, pid). pid is None if rebase failed.

## Telegram Notification Hyperlinks

Worker notifications display issue and PR numbers as clickable hyperlinks when a valid remote URL is available. The remote URL is resolved automatically from `git remote get-url origin`, or can be explicitly configured via `git.remote_url` in `.agentize.yaml`.

**Hyperlink format:**
- Issue links: `<a href="https://github.com/org/repo/issues/42">#42</a>`
- PR links: `<a href="https://github.com/org/repo/pull/99">#99</a>`

**Graceful degradation:** If the remote URL cannot be resolved or parsed, notifications display plain text (e.g., `#42`) without error.

### `_extract_repo_slug(remote_url: str) -> str | None`

Extract `org/repo` slug from a GitHub remote URL.

Handles common URL formats:
- `https://github.com/org/repo`
- `https://github.com/org/repo.git`
- `git@github.com:org/repo.git`

Returns `None` if the URL format is not recognized.

### `_format_worker_assignment_message(issue_no: int, issue_title: str, worker_id: int, issue_url: str | None) -> str`

Build an HTML-formatted Telegram message for worker assignment notification.

Includes issue link when `issue_url` is provided, otherwise displays issue number only.

### `_format_worker_completion_message(issue_no: int, worker_id: int, issue_url: str | None, pr_url: str | None = None) -> str`

Build an HTML-formatted Telegram message for worker completion notification.

Includes issue link when `issue_url` is provided, otherwise displays issue number only.
Includes PR link when `pr_url` is provided.

### `_resolve_session_dir(base_dir: str | None = None) -> Path`

Returns hooked-sessions directory path using `AGENTIZE_HOME` fallback.

**Parameters:**
- `base_dir`: Optional base directory override. If None, uses `AGENTIZE_HOME` or `.`

**Returns:** Path to `{base}/.tmp/hooked-sessions/` directory.

### `_load_issue_index(issue_no: int, session_dir: Path) -> str | None`

Reads issue index file and returns session_id.

**Parameters:**
- `issue_no`: GitHub issue number
- `session_dir`: Path to hooked-sessions directory

**Returns:** session_id string or None if index file not found.

### `_load_session_state(session_id: str, session_dir: Path) -> dict | None`

Loads session state JSON file.

**Parameters:**
- `session_id`: Session identifier
- `session_dir`: Path to hooked-sessions directory

**Returns:** Session state dict or None if not found.

### `_get_session_state_for_issue(issue_no: int, session_dir: Path) -> dict | None`

Combined lookup: issue index -> session state.

**Parameters:**
- `issue_no`: GitHub issue number
- `session_dir`: Path to hooked-sessions directory

**Returns:** Session state dict or None if not found.

### `_remove_issue_index(issue_no: int, session_dir: Path) -> None`

Remove issue index file after notification to prevent duplicates.

### `set_pr_number_for_issue(issue_no: int, pr_number: int, session_dir: Path | None = None) -> bool`

Best-effort persistence of PR number into session state.

**Parameters:**
- `issue_no`: GitHub issue number
- `pr_number`: PR number to store
- `session_dir`: Path to hooked-sessions directory (uses `AGENTIZE_HOME` if None)

**Returns:** `True` if successfully written, `False` otherwise (missing index or session file).

**Use case:** Called by the `open-pr` skill after successful PR creation to enable PR link in server completion notifications.
