#!/usr/bin/env python3
"""Polling server for GitHub Projects automation.

Polls GitHub Projects v2 for issues with "Plan Accepted" status and
`agentize:plan` label, then spawns worktrees for implementation.
"""

import argparse
import json
import os
import signal
import socket
import subprocess
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path


def _log(msg: str, level: str = "INFO") -> None:
    """Log with timestamp and source location."""
    frame = sys._getframe(1)
    filename = os.path.basename(frame.f_code.co_filename)
    lineno = frame.f_lineno
    func = frame.f_code.co_name
    timestamp = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")

    output = f"[{timestamp}] [{level}] [{filename}:{lineno}:{func}] {msg}"
    print(output, file=sys.stderr if level == "ERROR" else sys.stdout)


# GraphQL query for project items with Status field
GRAPHQL_QUERY = '''
query($org: String!, $projectNumber: Int!) {
  organization(login: $org) {
    projectV2(number: $projectNumber) {
      items(first: 100) {
        nodes {
          content {
            ... on Issue {
              number
              title
              labels(first: 10) {
                nodes { name }
              }
            }
          }
          fieldValueByName(name: "Status") {
            ... on ProjectV2ItemFieldSingleSelectValue {
              name
            }
          }
        }
      }
    }
  }
}
'''


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
    url = f'https://api.telegram.org/bot{token}/sendMessage'
    payload = {
        'chat_id': chat_id,
        'text': text,
        'parse_mode': 'HTML'
    }

    try:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            url, data=data,
            headers={'Content-Type': 'application/json'}
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result.get('ok', False)
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, TimeoutError) as e:
        _log(f"Failed to send Telegram message: {e}", level="ERROR")
        return False


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


def load_config() -> tuple[str, int]:
    """Load project config from .agentize.yaml."""
    yaml_path = Path('.agentize.yaml')
    if not yaml_path.exists():
        # Search parent directories
        current = Path.cwd()
        while current != current.parent:
            yaml_path = current / '.agentize.yaml'
            if yaml_path.exists():
                break
            current = current.parent
        else:
            raise FileNotFoundError(".agentize.yaml not found")

    # Simple YAML parsing (no external deps)
    org = None
    project_id = None
    with open(yaml_path) as f:
        for line in f:
            line = line.strip()
            if line.startswith('org:'):
                org = line.split(':', 1)[1].strip()
            elif line.startswith('id:'):
                project_id = int(line.split(':', 1)[1].strip())

    if not org or not project_id:
        raise ValueError(".agentize.yaml missing project.org or project.id")

    return org, project_id


def query_project_items(org: str, project_number: int) -> list[dict]:
    """Query GitHub Projects v2 for items."""
    query = GRAPHQL_QUERY.strip()

    result = subprocess.run(
        ['gh', 'api', 'graphql',
         '-f', f'query={query}',
         '-f', f'org={org}',
         '-F', f'projectNumber={project_number}'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        _log(f"GraphQL query failed: {result.stderr}", level="ERROR")
        if os.getenv('HANDSOFF_DEBUG'):
            _log(f"Query: {query[:100]}...", level="ERROR")
            _log(f"Variables: org={org}, projectNumber={project_number}", level="ERROR")
        return []

    data = json.loads(result.stdout)
    try:
        items = data['data']['organization']['projectV2']['items']['nodes']
        return items
    except (KeyError, TypeError):
        _log(f"Unexpected response structure: {result.stdout}", level="ERROR")
        return []


def filter_ready_issues(items: list[dict]) -> list[int]:
    """Filter items to issues with 'Plan Accepted' status and 'agentize:plan' label."""
    ready = []
    for item in items:
        content = item.get('content')
        if not content or 'number' not in content:
            continue

        # Check status
        status = item.get('fieldValueByName', {})
        if not status or status.get('name') != 'Plan Accepted':
            continue

        # Check label
        labels = content.get('labels', {}).get('nodes', [])
        label_names = [l['name'] for l in labels]
        if 'agentize:plan' not in label_names:
            continue

        ready.append(content['number'])

    return ready


def worktree_exists(issue_no: int) -> bool:
    """Check if a worktree exists for the given issue number."""
    result = subprocess.run(
        ['wt', 'resolve', str(issue_no)],
        capture_output=True, text=True
    )
    return result.returncode == 0


def spawn_worktree(issue_no: int) -> bool:
    """Spawn a new worktree for the given issue."""
    print(f"Spawning worktree for issue #{issue_no}...")
    result = subprocess.run(['wt', 'spawn', str(issue_no)])
    return result.returncode == 0


def run_server(period: int, tg_token: str | None = None, tg_chat_id: str | None = None) -> None:
    """Main polling loop.

    Args:
        period: Polling interval in seconds
        tg_token: Telegram Bot API token (optional, falls back to TG_API_TOKEN env)
        tg_chat_id: Telegram chat ID (optional, falls back to TG_CHAT_ID env)
    """
    org, project_id = load_config()
    print(f"Starting server: org={org}, project={project_id}, period={period}s")

    # Resolve Telegram credentials (CLI args take precedence over env vars)
    token = tg_token or os.getenv('TG_API_TOKEN', '')
    chat_id = tg_chat_id or os.getenv('TG_CHAT_ID', '')

    # Send startup notification if Telegram is configured
    if token and chat_id:
        notify_server_start(token, chat_id, org, project_id, period)
    else:
        print("Telegram notification skipped (no credentials configured)")

    # Setup signal handler for graceful shutdown
    running = [True]

    def signal_handler(signum, frame):
        print("\nShutting down...")
        running[0] = False

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    while running[0]:
        try:
            items = query_project_items(org, project_id)
            ready_issues = filter_ready_issues(items)

            for issue_no in ready_issues:
                if not worktree_exists(issue_no):
                    spawn_worktree(issue_no)
                else:
                    print(f"Issue #{issue_no}: worktree already exists, skipping")

            if running[0]:
                time.sleep(period)

        except Exception as e:
            _log(f"Error during poll: {e}", level="ERROR")
            if running[0]:
                time.sleep(period)


def main() -> None:
    """Entry point."""
    parser = argparse.ArgumentParser(
        description='Poll GitHub Projects for Plan Accepted issues'
    )
    parser.add_argument(
        '--period', default='5m',
        help='Polling interval (e.g., 5m, 300s). Default: 5m'
    )
    parser.add_argument(
        '--tg-token',
        help='Telegram Bot API token (or set TG_API_TOKEN env var)'
    )
    parser.add_argument(
        '--tg-chat-id',
        help='Telegram chat ID (or set TG_CHAT_ID env var)'
    )
    args = parser.parse_args()

    try:
        period_seconds = parse_period(args.period)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    run_server(period_seconds, args.tg_token, args.tg_chat_id)


if __name__ == '__main__':
    main()
