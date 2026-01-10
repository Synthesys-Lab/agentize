"""Shared Telegram utilities.

Provides common helpers for Telegram API integration.
"""


def escape_html(text: str) -> str:
    """Escape special HTML characters for Telegram HTML parse mode.

    Telegram HTML mode requires escaping: < > &

    Args:
        text: Raw text to escape

    Returns:
        HTML-safe string
    """
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
