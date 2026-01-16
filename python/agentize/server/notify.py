"""Telegram notification helpers for the server module."""

import os
import re
import socket
import sys

from agentize.telegram_utils import escape_html, telegram_request
from agentize.server.log import _log


# Telegram API timeout in seconds
TELEGRAM_API_TIMEOUT_SEC = 10


def parse_period(period_str: str) -> int:
    """Parse period string (e.g., '5m', '300s') to seconds."""
    if period_str.endswith('m'):
        return int(period_str[:-1]) * 60
    elif period_str.endswith('s'):
        return int(period_str[:-1])
    else:
        raise ValueError(f"Invalid period format: {period_str}. Use Nm or Ns.")


def send_telegram_message(token: str, chat_id: str, text: str) -> bool:
    """Send a message to Telegram.

    Args:
        token: Telegram Bot API token
        chat_id: Chat ID to send to
        text: Message text (supports HTML parse mode)

    Returns:
        True if successful, False otherwise
    """
    result = telegram_request(
        token=token,
        method='sendMessage',
        payload={'chat_id': chat_id, 'text': text, 'parse_mode': 'HTML'},
        timeout_sec=TELEGRAM_API_TIMEOUT_SEC,
        on_error=lambda e: _log(f"Failed to send Telegram message: {e}", level="ERROR")
    )
    return result.get('ok', False) if result else False


def notify_server_start(token: str, chat_id: str, org: str, project_id: int, period: int) -> None:
    """Send server startup notification to Telegram.

    Args:
        token: Telegram Bot API token
        chat_id: Chat ID to send to
        org: GitHub organization
        project_id: GitHub project number
        period: Polling interval in seconds
    """
    hostname = socket.gethostname()
    cwd = os.getcwd()

    message = (
        f"🚀 <b>Agentize Server Started</b>\n\n"
        f"Host: <code>{hostname}</code>\n"
        f"Project: <code>{org}/{project_id}</code>\n"
        f"Period: <code>{period}s</code>\n"
        f"Working Dir: <code>{cwd}</code>"
    )

    if send_telegram_message(token, chat_id, message):
        print("Telegram notification sent")
    else:
        print("Warning: Failed to send Telegram startup notification", file=sys.stderr)


def _extract_repo_slug(remote_url: str) -> str | None:
    """Extract org/repo slug from a GitHub remote URL.

    Handles:
    - https://github.com/org/repo
    - https://github.com/org/repo.git
    - git@github.com:org/repo.git

    Returns:
        org/repo string or None if URL format not recognized
    """
    if not remote_url:
        return None

    # HTTPS format: https://github.com/org/repo[.git]
    https_match = re.match(r'https://github\.com/([^/]+)/([^/]+?)(?:\.git)?$', remote_url)
    if https_match:
        return f"{https_match.group(1)}/{https_match.group(2)}"

    # SSH format: git@github.com:org/repo.git
    ssh_match = re.match(r'git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$', remote_url)
    if ssh_match:
        return f"{ssh_match.group(1)}/{ssh_match.group(2)}"

    return None


def _format_worker_assignment_message(
    issue_no: int,
    issue_title: str,
    worker_id: int,
    issue_url: str | None
) -> str:
    """Build HTML-formatted Telegram message for worker assignment.

    Args:
        issue_no: GitHub issue number
        issue_title: Issue title (will be HTML-escaped)
        worker_id: Worker slot ID
        issue_url: Full GitHub issue URL or None

    Returns:
        HTML-formatted message for Telegram
    """
    escaped_title = escape_html(issue_title)

    if issue_url:
        issue_ref = f'<a href="{issue_url}">#{issue_no}</a>'
    else:
        issue_ref = f'#{issue_no}'

    return (
        f"🔧 <b>Worker Assignment</b>\n\n"
        f"Issue: {issue_ref} {escaped_title}\n"
        f"Worker: {worker_id}"
    )


def _format_worker_completion_message(
    issue_no: int,
    worker_id: int,
    issue_url: str | None,
    pr_url: str | None = None
) -> str:
    """Build HTML-formatted Telegram message for worker completion.

    Args:
        issue_no: GitHub issue number
        worker_id: Worker slot ID
        issue_url: Full GitHub issue URL or None
        pr_url: Full GitHub PR URL or None

    Returns:
        HTML-formatted message for Telegram
    """
    if issue_url:
        issue_ref = f'<a href="{issue_url}">#{issue_no}</a>'
    else:
        issue_ref = f'#{issue_no}'

    lines = [
        f"✅ <b>Worker Completed</b>\n",
        f"Issue: {issue_ref}",
    ]

    if pr_url:
        pr_number = pr_url.rstrip('/').split('/')[-1]
        lines.append(f"PR: <a href=\"{pr_url}\">#{pr_number}</a>")

    lines.append(f"Worker: {worker_id}")

    return '\n'.join(lines)
