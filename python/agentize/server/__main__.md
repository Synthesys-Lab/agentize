# Server Module Interface

## External Interface

Functions exported via `__init__.py`:

### `run_server(period: int, tg_token: str | None = None, tg_chat_id: str | None = None) -> None`

Main polling loop that monitors GitHub Projects for ready issues.

**Parameters:**
- `period`: Polling interval in seconds
- `tg_token`: Telegram Bot API token (optional, falls back to `TG_API_TOKEN` env)
- `tg_chat_id`: Telegram chat ID (optional, falls back to `TG_CHAT_ID` env)

**Behavior:**
- Loads config from `.agentize.yaml`
- Sends startup notification if Telegram configured
- Polls project items at `period` intervals
- Spawns worktrees for issues with "Plan Accepted" status and `agentize:plan` label
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

### `load_config() -> tuple[str, int]`

Load project org and ID from `.agentize.yaml`.

### `query_project_items(org: str, project_number: int) -> list[dict]`

Query GitHub Projects v2 for items via GraphQL.

### `filter_ready_issues(items: list[dict]) -> list[int]`

Filter items to issues with "Plan Accepted" status and `agentize:plan` label.
When `HANDSOFF_DEBUG=1`, logs per-issue inspection with status, labels, and rejection reasons.

### `worktree_exists(issue_no: int) -> bool`

Check if a worktree exists for the given issue number.

### `spawn_worktree(issue_no: int) -> bool`

Spawn a new worktree for the given issue via `wt spawn`.

### `_run_wt(args: str, capture_output: bool = False) -> subprocess.CompletedProcess`

Run wt command via bash (wt is a shell function, not an executable).
