# Telegram Utilities Interface

Shared utilities for Telegram Bot API integration used by the server and permission modules.

## External Interface

### `escape_html(text: str) -> str`

Escape special HTML characters for Telegram HTML parse mode.

**Parameters:**
- `text`: Raw text string to escape

**Returns:** HTML-safe string with `<`, `>`, and `&` escaped

**Escapes:**
- `&` → `&amp;`
- `<` → `&lt;`
- `>` → `&gt;`

### `telegram_request(...) -> dict | None`

Make an HTTP request to the Telegram Bot API.

```python
def telegram_request(
    token: str,
    method: str,
    payload: dict | None = None,
    timeout_sec: int = 10,
    on_error: Callable[[Exception], None] | None = None,
    urlopen_fn: Callable[..., Any] | None = None
) -> dict | None
```

**Parameters:**
- `token`: Telegram Bot API token
- `method`: API method name (e.g., `sendMessage`, `getUpdates`)
- `payload`: Request payload dict (optional, JSON-encoded when provided)
- `timeout_sec`: Request timeout in seconds (default: 10)
- `on_error`: Callback invoked with exception on failure (optional)
- `urlopen_fn`: Custom URL opener for testing (optional, defaults to `urllib.request.urlopen`)

**Returns:** Parsed JSON response dict on success, `None` on error

**Behavior:**
- Builds URL: `https://api.telegram.org/bot{token}/{method}`
- JSON-encodes payload with `Content-Type: application/json` header
- Returns parsed JSON dict on 2xx response
- Returns `None` on network/HTTP/JSON errors and calls `on_error` if provided

**Usage:**

```python
from agentize.telegram_utils import telegram_request

# Basic usage
result = telegram_request(
    token="123:ABC",
    method="sendMessage",
    payload={"chat_id": "456", "text": "Hello"}
)

# With error handling
def handle_error(e):
    print(f"Telegram error: {e}")

result = telegram_request(
    token="123:ABC",
    method="getUpdates",
    on_error=handle_error
)

# For testing with injected urlopen
def mock_urlopen(req, timeout=None):
    # Return mock response
    ...

result = telegram_request(
    token="fake",
    method="sendMessage",
    urlopen_fn=mock_urlopen
)
```

## Internal Usage

- `python/agentize/server/__main__.py`: Uses `telegram_request` via `send_telegram_message` for notifications
- `python/agentize/permission/determine.py`: Uses `telegram_request` via `_tg_api_request` for approval workflow
