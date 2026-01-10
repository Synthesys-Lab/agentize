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

Returns: `(org, project_id, remote_url)` where `remote_url` is the `git.remote_url` value or `None` if not configured.

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

### `worktree_exists(issue_no: int) -> bool`

Check if a worktree exists for the given issue number.

### `spawn_worktree(issue_no: int) -> tuple[bool, int | None]`

Spawn a new worktree for the given issue via `wt spawn`.

**Returns:** Tuple of (success, pid). pid is None if spawn failed.

Note: Uses `run_shell_function()` from `agentize.shell` for shell invocation.

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
