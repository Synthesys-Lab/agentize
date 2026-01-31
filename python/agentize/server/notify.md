# notify.py

Telegram notification helpers for the server module.

## External Interface

### parse_period(period_str: str) -> int

Parse period strings like "5m" or "300s" into seconds.

**Parameters:**
- `period_str`: String ending in `m` (minutes) or `s` (seconds).

**Returns:**
- Integer number of seconds.

**Errors:**
- Raises `ValueError` for unsupported formats.

### send_telegram_message(token: str, chat_id: str, text: str) -> bool

Send a Telegram message using HTML parse mode.

**Parameters:**
- `token`: Telegram Bot API token.
- `chat_id`: Chat ID to send to.
- `text`: Message content (HTML-escaped by callers when needed).

**Returns:**
- `True` on success, `False` on failure.

### notify_server_start(token: str, chat_id: str, org: str, project_id: int, period: int) -> None

Send a startup notification that includes hostname, project identifier, and working directory.

**Parameters:**
- `token`: Telegram Bot API token.
- `chat_id`: Chat ID to send to.
- `org`: GitHub organization or owner.
- `project_id`: GitHub project number.
- `period`: Polling interval in seconds.

## Internal Helpers

### _extract_repo_slug(remote_url: str) -> Optional[str]

Extract an `org/repo` slug from HTTPS or SSH GitHub remote URLs.
Returns `None` when the URL format is not recognized.

### _format_worker_assignment_message(issue_no: int, issue_title: str, worker_id: int, issue_url: Optional[str]) -> str

Build an HTML-formatted assignment message with a link when `issue_url` is provided.

### _format_worker_completion_message(issue_no: int, worker_id: int, issue_url: Optional[str], pr_url: Optional[str] = None) -> str

Build an HTML-formatted completion message with issue and optional PR links.

## Design Notes

- The module uses HTML parse mode to allow safe links and bold headings.
- Title strings are escaped via `escape_html` before embedding in messages.
- API timeout is fixed by `TELEGRAM_API_TIMEOUT_SEC` for predictable retries.
