"""Shared Telegram utilities.

Provides common helpers for Telegram API integration.
"""

from __future__ import annotations

import json
import urllib.request
import urllib.error
from typing import Any, Callable, Optional


def escape_html(text: str) -> str:
    """Escape special HTML characters for Telegram HTML parse mode.

    Telegram HTML mode requires escaping: < > &

    Args:
        text: Raw text to escape

    Returns:
        HTML-safe string
    """
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def telegram_request(
    token: str,
    method: str,
    payload: Optional[dict] = None,
    timeout_sec: int = 10,
    on_error: Optional[Callable[[Exception], None]] = None,
    urlopen_fn: Optional[Callable[..., Any]] = None
) -> Optional[dict]:
    """Make an HTTP request to the Telegram Bot API.

    Args:
        token: Telegram Bot API token
        method: API method name (e.g., 'sendMessage', 'getUpdates')
        payload: Request payload dict (optional, JSON-encoded when provided)
        timeout_sec: Request timeout in seconds (default: 10)
        on_error: Callback invoked with exception on failure (optional)
        urlopen_fn: Custom URL opener for testing (optional)

    Returns:
        Parsed JSON response dict on success, None on error
    """
    if urlopen_fn is None:
        urlopen_fn = urllib.request.urlopen

    url = f'https://api.telegram.org/bot{token}/{method}'

    try:
        if payload:
            data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(
                url, data=data,
                headers={'Content-Type': 'application/json'}
            )
        else:
            req = urllib.request.Request(url)

        with urlopen_fn(req, timeout=timeout_sec) as response:
            return json.loads(response.read().decode('utf-8'))
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, TimeoutError) as e:
        if on_error:
            on_error(e)
        return None
