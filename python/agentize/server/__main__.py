#!/usr/bin/env python3
"""Polling server for GitHub Projects automation.

Polls GitHub Projects v2 for issues with "Plan Accepted" status and
`agentize:plan` label, then spawns worktrees for implementation.
"""

import argparse
import json
import os
import re
import signal
import socket
import subprocess
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

from agentize.shell import run_shell_function
from agentize.telegram_utils import escape_html, telegram_request


# Cache for project GraphQL ID (org/project_number -> GraphQL ID)
_project_id_cache: dict[tuple[str, int], str] = {}


def _log(msg: str, level: str = "INFO") -> None:
    """Log with timestamp and source location."""
    frame = sys._getframe(1)
    filename = os.path.basename(frame.f_code.co_filename)
    lineno = frame.f_lineno
    func = frame.f_code.co_name
    timestamp = datetime.now().strftime("%y-%m-%d-%H:%M:%S")

    output = f"[{timestamp}] [{level}] [{filename}:{lineno}:{func}] {msg}"
    print(output, file=sys.stderr if level == "ERROR" else sys.stdout)


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
    issue_url: str | None
) -> str:
    """Build HTML-formatted Telegram message for worker completion.

    Args:
        issue_no: GitHub issue number
        worker_id: Worker slot ID
        issue_url: Full GitHub issue URL or None

    Returns:
        HTML-formatted message for Telegram
    """
    if issue_url:
        issue_ref = f'<a href="{issue_url}">#{issue_no}</a>'
    else:
        issue_ref = f'#{issue_no}'

    return (
        f"✅ <b>Worker Completed</b>\n\n"
        f"Issue: {issue_ref}\n"
        f"Worker: {worker_id}"
    )


def _resolve_session_dir(base_dir: str | None = None) -> Path:
    """Returns hooked-sessions directory using AGENTIZE_HOME fallback.

    Args:
        base_dir: Optional base directory override. If None, uses AGENTIZE_HOME or '.'

    Returns:
        Path to hooked-sessions directory
    """
    base = base_dir or os.getenv('AGENTIZE_HOME', '.')
    return Path(base) / '.tmp' / 'hooked-sessions'


def _load_issue_index(issue_no: int, session_dir: Path) -> str | None:
    """Reads issue index and returns session_id.

    Args:
        issue_no: GitHub issue number
        session_dir: Path to hooked-sessions directory

    Returns:
        session_id string or None if index file not found
    """
    index_file = session_dir / 'by-issue' / f'{issue_no}.json'
    if not index_file.exists():
        return None

    try:
        with open(index_file) as f:
            data = json.load(f)
            return data.get('session_id')
    except (json.JSONDecodeError, OSError):
        return None


def _load_session_state(session_id: str, session_dir: Path) -> dict | None:
    """Loads session JSON.

    Args:
        session_id: Session identifier
        session_dir: Path to hooked-sessions directory

    Returns:
        Session state dict or None if not found
    """
    session_file = session_dir / f'{session_id}.json'
    if not session_file.exists():
        return None

    try:
        with open(session_file) as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return None


def _get_session_state_for_issue(issue_no: int, session_dir: Path) -> dict | None:
    """Combined lookup: issue index -> session state.

    Args:
        issue_no: GitHub issue number
        session_dir: Path to hooked-sessions directory

    Returns:
        Session state dict or None if not found
    """
    session_id = _load_issue_index(issue_no, session_dir)
    if session_id is None:
        return None
    return _load_session_state(session_id, session_dir)


def _remove_issue_index(issue_no: int, session_dir: Path) -> None:
    """Remove issue index file after notification to prevent duplicates.

    Args:
        issue_no: GitHub issue number
        session_dir: Path to hooked-sessions directory
    """
    index_file = session_dir / 'by-issue' / f'{issue_no}.json'
    try:
        index_file.unlink(missing_ok=True)
    except OSError:
        pass  # Best effort cleanup


def load_config() -> tuple[str, int, str | None]:
    """Load project config from .agentize.yaml.

    Returns:
        Tuple of (org, project_id, remote_url) where remote_url may be None.
    """
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
    remote_url = None
    with open(yaml_path) as f:
        for line in f:
            line = line.strip()
            if line.startswith('org:'):
                org = line.split(':', 1)[1].strip()
            elif line.startswith('id:'):
                project_id = int(line.split(':', 1)[1].strip())
            elif line.startswith('remote_url:'):
                remote_url = line.split(':', 1)[1].strip()
                # Handle URLs with : in them (e.g., https://...)
                if remote_url.startswith('https') or remote_url.startswith('git@'):
                    # Re-read the full value after 'remote_url:'
                    remote_url = line.split('remote_url:', 1)[1].strip()

    if not org or not project_id:
        raise ValueError(".agentize.yaml missing project.org or project.id")

    return org, project_id, remote_url


def get_repo_owner_name() -> tuple[str, str]:
    """Resolve repository owner and name from git remote origin."""
    result = subprocess.run(
        ['git', 'remote', 'get-url', 'origin'],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"Failed to get git remote: {result.stderr}")

    url = result.stdout.strip()
    # Handle SSH format: git@github.com:owner/repo.git
    if url.startswith('git@'):
        path = url.split(':')[1]
    # Handle HTTPS format: https://github.com/owner/repo.git
    elif 'github.com' in url:
        path = url.split('github.com/')[1]
    else:
        raise RuntimeError(f"Unrecognized git remote format: {url}")

    # Remove .git suffix and trailing slash properly
    if path.endswith('/'):
        path = path[:-1]
    if path.endswith('.git'):
        path = path[:-4]
    parts = path.split('/')
    if len(parts) >= 2:
        return parts[0], parts[1]
    raise RuntimeError(f"Cannot parse owner/repo from: {url}")


def lookup_project_graphql_id(org: str, project_number: int) -> str:
    """Convert organization and project number into ProjectV2 GraphQL ID.

    Result is cached to avoid repeated lookups.
    """
    cache_key = (org, project_number)
    if cache_key in _project_id_cache:
        return _project_id_cache[cache_key]

    query = '''
query($org: String!, $projectNumber: Int!) {
  organization(login: $org) {
    projectV2(number: $projectNumber) {
      id
    }
  }
}
'''
    result = subprocess.run(
        ['gh', 'api', 'graphql',
         '-f', f'query={query.strip()}',
         '-f', f'org={org}',
         '-F', f'projectNumber={project_number}'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        _log(f"Failed to lookup project ID: {result.stderr}", level="ERROR")
        return ''

    try:
        data = json.loads(result.stdout)
        project_id = data['data']['organization']['projectV2']['id']
        _project_id_cache[cache_key] = project_id
        return project_id
    except (KeyError, TypeError, json.JSONDecodeError) as e:
        _log(f"Failed to parse project ID response: {e}", level="ERROR")
        return ''


def discover_candidate_issues(owner: str, repo: str) -> list[int]:
    """Discover open issues with agentize:plan label using gh issue list."""
    result = subprocess.run(
        ['gh', 'issue', 'list',
         '-R', f'{owner}/{repo}',
         '--label', 'agentize:plan',
         '--state', 'open',
         '--json', 'number',
         '--jq', '.[].number'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        _log(f"Failed to list issues: {result.stderr}", level="ERROR")
        return []

    issues = []
    for line in result.stdout.strip().split('\n'):
        line = line.strip()
        if line:
            # Handle both tab-separated format and plain number format
            try:
                issue_no = int(line.split('\t')[0])
                issues.append(issue_no)
            except (ValueError, IndexError):
                continue
    return issues


# GraphQL query to get an issue's project status
ISSUE_STATUS_QUERY = '''
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      projectItems(first: 20) {
        nodes {
          project { id }
          fieldValues(first: 50) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2SingleSelectField { name } }
                name
              }
            }
          }
        }
      }
    }
  }
}
'''


def query_issue_project_status(owner: str, repo: str, issue_no: int, project_id: str) -> str:
    """Fetch an issue's Status field value for the configured project.

    Returns the status string (e.g., "Plan Accepted") or empty string if not found.
    """
    result = subprocess.run(
        ['gh', 'api', 'graphql',
         '-f', f'query={ISSUE_STATUS_QUERY.strip()}',
         '-f', f'owner={owner}',
         '-f', f'repo={repo}',
         '-F', f'number={issue_no}'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        _log(f"Failed to query issue #{issue_no} status: {result.stderr}", level="ERROR")
        if os.getenv('HANDSOFF_DEBUG'):
            _log(f"Variables: owner={owner}, repo={repo}, number={issue_no}", level="ERROR")
        return ''

    try:
        data = json.loads(result.stdout)
        project_items = data['data']['repository']['issue']['projectItems']['nodes']

        # Find the project item matching our project ID
        for item in project_items:
            if item.get('project', {}).get('id') != project_id:
                continue

            # Find the Status field value
            for field_value in item.get('fieldValues', {}).get('nodes', []):
                field_name = field_value.get('field', {}).get('name', '')
                if field_name == 'Status':
                    return field_value.get('name', '')

        return ''
    except (KeyError, TypeError, json.JSONDecodeError) as e:
        _log(f"Failed to parse issue status response: {e}", level="ERROR")
        return ''


def query_project_items(org: str, project_number: int) -> list[dict]:
    """Query GitHub Projects v2 for items using label-first discovery.

    Uses gh issue list to discover candidates with agentize:plan label,
    then performs per-issue GraphQL queries to check project status.
    """
    # Get repo owner/name for gh issue list
    try:
        owner, repo = get_repo_owner_name()
    except RuntimeError as e:
        _log(f"Failed to get repo info: {e}", level="ERROR")
        return []

    # Lookup project GraphQL ID for status matching
    project_id = lookup_project_graphql_id(org, project_number)
    if not project_id:
        _log("Failed to lookup project GraphQL ID", level="ERROR")
        return []

    # Discover candidates via label-first query
    candidate_issues = discover_candidate_issues(owner, repo)
    if not candidate_issues:
        if os.getenv('HANDSOFF_DEBUG'):
            _log("No candidate issues found with agentize:plan label")
        return []

    if os.getenv('HANDSOFF_DEBUG'):
        _log(f"Found {len(candidate_issues)} candidate issues: {candidate_issues}")

    # Build items list with per-issue status lookups
    items = []
    for issue_no in candidate_issues:
        status = query_issue_project_status(owner, repo, issue_no, project_id)

        # Build item in the same format expected by filter_ready_issues
        item = {
            'content': {
                'number': issue_no,
                'labels': {'nodes': [{'name': 'agentize:plan'}]}  # Already filtered by label
            },
            'fieldValueByName': {'name': status} if status else None
        }
        items.append(item)

    return items


def filter_ready_issues(items: list[dict]) -> list[int]:
    """Filter items to issues with 'Plan Accepted' status and 'agentize:plan' label."""
    debug = os.getenv('HANDSOFF_DEBUG')
    ready = []
    skip_status = 0
    skip_label = 0

    for item in items:
        content = item.get('content')
        if not content or 'number' not in content:
            continue

        issue_no = content['number']
        status_field = item.get('fieldValueByName') or {}
        status_name = status_field.get('name', '')
        labels = content.get('labels', {}).get('nodes', [])
        label_names = [l['name'] for l in labels]

        # Check status
        if status_name != 'Plan Accepted':
            if debug:
                print(f"[issue-filter] #{issue_no} status={status_name} labels={label_names} -> SKIP (status != Plan Accepted)", file=sys.stderr)
            skip_status += 1
            continue

        # Check label
        if 'agentize:plan' not in label_names:
            if debug:
                print(f"[issue-filter] #{issue_no} status={status_name} labels={label_names} -> SKIP (missing agentize:plan label)", file=sys.stderr)
            skip_label += 1
            continue

        if debug:
            print(f"[issue-filter] #{issue_no} status={status_name} labels={label_names} -> READY", file=sys.stderr)
        ready.append(issue_no)

    if debug:
        total_skip = skip_status + skip_label
        print(f"[issue-filter] Summary: {len(ready)} ready, {total_skip} skipped ({skip_status} wrong status, {skip_label} missing label)", file=sys.stderr)

    return ready


def discover_candidate_prs(owner: str, repo: str) -> list[dict]:
    """Discover open PRs with agentize:pr label.

    Returns:
        List of PR metadata dicts with number, headRefName, mergeable fields.
    """
    result = subprocess.run(
        ['gh', 'pr', 'list',
         '-R', f'{owner}/{repo}',
         '--label', 'agentize:pr',
         '--state', 'open',
         '--json', 'number,headRefName,mergeable,body,closingIssuesReferences'],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        _log(f"Failed to list PRs: {result.stderr}", level="ERROR")
        return []

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        _log(f"Failed to parse PR list response: {e}", level="ERROR")
        return []


def filter_conflicting_prs(prs: list[dict]) -> list[int]:
    """Filter PRs to those with merge conflicts.

    Returns PR numbers where mergeable == "CONFLICTING".
    Skips PRs with mergeable == "UNKNOWN" (retry on next poll).
    """
    debug = os.getenv('HANDSOFF_DEBUG')
    conflicting = []

    for pr in prs:
        pr_no = pr.get('number')
        mergeable = pr.get('mergeable', '')

        if mergeable == 'CONFLICTING':
            if debug:
                print(f"[pr-rebase] #{pr_no} mergeable=CONFLICTING -> QUEUE", file=sys.stderr)
            conflicting.append(pr_no)
        elif mergeable == 'UNKNOWN':
            if debug:
                print(f"[pr-rebase] #{pr_no} mergeable=UNKNOWN -> SKIP (retry next poll)", file=sys.stderr)
        else:
            if debug:
                print(f"[pr-rebase] #{pr_no} mergeable={mergeable} -> SKIP (healthy)", file=sys.stderr)

    return conflicting


def resolve_issue_from_pr(pr: dict) -> int | None:
    """Resolve issue number from PR metadata.

    Fallback order:
    1. Branch name pattern: issue-<N>
    2. closingIssuesReferences
    3. PR body #<N> pattern
    """
    # Fallback 1: Branch name
    head_ref = pr.get('headRefName', '')
    match = re.match(r'issue-(\d+)', head_ref)
    if match:
        return int(match.group(1))

    # Fallback 2: closingIssuesReferences
    closing_refs = pr.get('closingIssuesReferences', [])
    if closing_refs and len(closing_refs) > 0:
        first_ref = closing_refs[0]
        if isinstance(first_ref, dict) and 'number' in first_ref:
            return first_ref['number']

    # Fallback 3: PR body #N pattern
    body = pr.get('body', '')
    if body:
        body_match = re.search(r'#(\d+)', body)
        if body_match:
            return int(body_match.group(1))

    return None


def rebase_worktree(pr_no: int) -> tuple[bool, int | None]:
    """Rebase a PR's worktree using wt rebase command.

    Returns:
        Tuple of (success, pid). pid is None if rebase failed.
    """
    _log(f"Rebasing worktree for PR #{pr_no}...")
    result = run_shell_function(f'wt rebase {pr_no} --headless', capture_output=True)
    if result.returncode != 0:
        return False, None

    # Parse PID from output
    pid = None
    for line in result.stdout.splitlines():
        if 'PID' in line:
            match = re.search(r'PID[:\s]+(\d+)', line)
            if match:
                pid = int(match.group(1))
                break
    return True, pid


def worktree_exists(issue_no: int) -> bool:
    """Check if a worktree exists for the given issue number."""
    result = run_shell_function(f'wt pathto {issue_no}', capture_output=True)
    return result.returncode == 0


def spawn_worktree(issue_no: int) -> tuple[bool, int | None]:
    """Spawn a new worktree for the given issue.

    Returns:
        Tuple of (success, pid). pid is None if spawn failed.
    """
    print(f"Spawning worktree for issue #{issue_no}...")
    result = run_shell_function(f'wt spawn {issue_no} --headless', capture_output=True)
    if result.returncode != 0:
        return False, None

    # Parse PID from output (format: "PID: 12345")
    pid = None
    for line in result.stdout.splitlines():
        if 'PID' in line:
            match = re.search(r'PID[:\s]+(\d+)', line)
            if match:
                pid = int(match.group(1))
                break
    return True, pid


# Worker status file management
DEFAULT_WORKERS_DIR = '.tmp/workers'


def init_worker_status_files(num_workers: int, workers_dir: str = DEFAULT_WORKERS_DIR) -> None:
    """Initialize worker status files with state=FREE.

    Creates the workers directory and N status files, one per worker slot.
    """
    workers_path = Path(workers_dir)
    workers_path.mkdir(parents=True, exist_ok=True)

    for i in range(num_workers):
        status_file = workers_path / f'worker-{i}.status'
        # Only reset to FREE if file doesn't exist or is corrupted
        if not status_file.exists():
            write_worker_status(i, 'FREE', None, None, workers_dir)
        else:
            # Validate existing file, reset if corrupted
            try:
                status = read_worker_status(i, workers_dir)
                if 'state' not in status:
                    write_worker_status(i, 'FREE', None, None, workers_dir)
            except Exception:
                write_worker_status(i, 'FREE', None, None, workers_dir)


def read_worker_status(worker_id: int, workers_dir: str = DEFAULT_WORKERS_DIR) -> dict:
    """Read and parse a worker status file.

    Returns:
        Dict with keys: state (required), issue (optional), pid (optional)
    """
    status_file = Path(workers_dir) / f'worker-{worker_id}.status'

    if not status_file.exists():
        return {'state': 'FREE'}

    # Default to FREE in case file is empty or malformed
    result = {'state': 'FREE'}

    with open(status_file) as f:
        for line in f:
            line = line.strip()
            if '=' in line:
                key, value = line.split('=', 1)
                if key == 'state':
                    result['state'] = value
                elif key == 'issue':
                    try:
                        result['issue'] = int(value)
                    except ValueError:
                        pass  # Skip malformed value
                elif key == 'pid':
                    try:
                        result['pid'] = int(value)
                    except ValueError:
                        pass  # Skip malformed value

    return result


def write_worker_status(
    worker_id: int,
    state: str,
    issue: int | None,
    pid: int | None,
    workers_dir: str = DEFAULT_WORKERS_DIR
) -> None:
    """Write worker status to file atomically.

    Uses write-to-temp + rename for atomic updates.
    """
    workers_path = Path(workers_dir)
    workers_path.mkdir(parents=True, exist_ok=True)

    status_file = workers_path / f'worker-{worker_id}.status'
    tmp_file = workers_path / f'worker-{worker_id}.status.tmp'

    lines = [f'state={state}']
    if issue is not None:
        lines.append(f'issue={issue}')
    if pid is not None:
        lines.append(f'pid={pid}')

    with open(tmp_file, 'w') as f:
        f.write('\n'.join(lines) + '\n')

    # Atomic rename
    tmp_file.rename(status_file)


def get_free_worker(num_workers: int, workers_dir: str = DEFAULT_WORKERS_DIR) -> int | None:
    """Find the first FREE worker slot.

    Returns:
        Worker ID (0-indexed) or None if all workers are busy.
    """
    for i in range(num_workers):
        status = read_worker_status(i, workers_dir)
        if status.get('state') == 'FREE':
            return i
    return None


def check_worker_liveness(worker_id: int, workers_dir: str = DEFAULT_WORKERS_DIR) -> bool:
    """Check if a worker's PID is still running.

    Returns:
        True if worker is FREE or BUSY with a live PID.
        False if worker is BUSY with a dead PID.
    """
    status = read_worker_status(worker_id, workers_dir)
    if status.get('state') != 'BUSY':
        return True

    pid = status.get('pid')
    if pid is None:
        return True  # No PID to check

    # Check if process is still running
    try:
        os.kill(pid, 0)  # Signal 0 just checks if process exists
        return True
    except OSError:
        return False


def cleanup_dead_workers(
    num_workers: int,
    workers_dir: str = DEFAULT_WORKERS_DIR,
    *,
    tg_token: str | None = None,
    tg_chat_id: str | None = None,
    repo_slug: str | None = None,
    session_dir: Path | None = None
) -> None:
    """Mark workers with dead PIDs as FREE and send completion notifications.

    Args:
        num_workers: Number of worker slots
        workers_dir: Directory containing worker status files
        tg_token: Telegram Bot API token (optional)
        tg_chat_id: Telegram chat ID (optional)
        repo_slug: GitHub repo slug for issue URLs (optional)
        session_dir: Path to hooked-sessions directory (optional)
    """
    for i in range(num_workers):
        if not check_worker_liveness(i, workers_dir):
            status = read_worker_status(i, workers_dir)
            issue_no = status.get('issue')
            _log(f"Worker {i} PID {status.get('pid')} is dead, marking as FREE")

            # Check for completion notification conditions
            if tg_token and tg_chat_id and issue_no and session_dir:
                session_state = _get_session_state_for_issue(issue_no, session_dir)
                if session_state and session_state.get('state') == 'done':
                    issue_url = f"https://github.com/{repo_slug}/issues/{issue_no}" if repo_slug else None
                    msg = _format_worker_completion_message(issue_no, i, issue_url)
                    if send_telegram_message(tg_token, tg_chat_id, msg):
                        _log(f"Sent completion notification for issue #{issue_no}")
                        # Remove issue index to prevent duplicate notifications
                        _remove_issue_index(issue_no, session_dir)

            write_worker_status(i, 'FREE', None, None, workers_dir)


def run_server(
    period: int,
    tg_token: str | None = None,
    tg_chat_id: str | None = None,
    num_workers: int = 5
) -> None:
    """Main polling loop.

    Args:
        period: Polling interval in seconds
        tg_token: Telegram Bot API token (optional, falls back to TG_API_TOKEN env)
        tg_chat_id: Telegram chat ID (optional, falls back to TG_CHAT_ID env)
        num_workers: Maximum concurrent workers (0 = unlimited)
    """
    org, project_id, remote_url = load_config()
    print(f"Starting server: org={org}, project={project_id}, period={period}s, workers={num_workers}")

    # Extract repo slug for issue links (computed once)
    repo_slug = _extract_repo_slug(remote_url) if remote_url else None

    # Resolve Telegram credentials (CLI args take precedence over env vars)
    token = tg_token or os.getenv('TG_API_TOKEN', '')
    chat_id = tg_chat_id or os.getenv('TG_CHAT_ID', '')

    # Resolve session directory for completion notifications
    session_dir = _resolve_session_dir()

    # Initialize worker status files (if num_workers > 0)
    if num_workers > 0:
        init_worker_status_files(num_workers)
        cleanup_dead_workers(
            num_workers,
            tg_token=token,
            tg_chat_id=chat_id,
            repo_slug=repo_slug,
            session_dir=session_dir
        )

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
            # Clean up dead workers before polling
            if num_workers > 0:
                cleanup_dead_workers(
                    num_workers,
                    tg_token=token,
                    tg_chat_id=chat_id,
                    repo_slug=repo_slug,
                    session_dir=session_dir
                )

            items = query_project_items(org, project_id)
            ready_issues = filter_ready_issues(items)

            # Build issue titles map (without changing filter_ready_issues return type)
            issue_titles: dict[int, str] = {}
            for item in items:
                content = item.get('content')
                if content and 'number' in content:
                    issue_titles[content['number']] = content.get('title', '')

            for issue_no in ready_issues:
                if worktree_exists(issue_no):
                    print(f"Issue #{issue_no}: worktree already exists, skipping")
                    continue

                # Check worker availability (if bounded)
                if num_workers > 0:
                    worker_id = get_free_worker(num_workers)
                    if worker_id is None:
                        print(f"All {num_workers} workers busy, waiting for next poll")
                        break

                    # Mark worker as busy before spawning
                    write_worker_status(worker_id, 'BUSY', issue_no, None)
                    success, pid = spawn_worktree(issue_no)
                    if success:
                        write_worker_status(worker_id, 'BUSY', issue_no, pid)
                        print(f"issue #{issue_no} is assigned to worker {worker_id}")

                        # Send Telegram notification if configured
                        if token and chat_id:
                            issue_title = issue_titles.get(issue_no, '')
                            issue_url = f"https://github.com/{repo_slug}/issues/{issue_no}" if repo_slug else None
                            msg = _format_worker_assignment_message(issue_no, issue_title, worker_id, issue_url)
                            send_telegram_message(token, chat_id, msg)
                    else:
                        write_worker_status(worker_id, 'FREE', None, None)
                        _log(f"Failed to spawn worktree for issue #{issue_no}", level="ERROR")
                else:
                    # Unlimited workers mode
                    success, _ = spawn_worktree(issue_no)
                    if not success:
                        _log(f"Failed to spawn worktree for issue #{issue_no}", level="ERROR")

            # PR auto-rebase: discover conflicting PRs and rebase their worktrees
            try:
                owner, repo = get_repo_owner_name()
                prs = discover_candidate_prs(owner, repo)
                conflicting_prs = filter_conflicting_prs(prs)

                # Build PR metadata map for issue resolution
                pr_metadata: dict[int, dict] = {pr['number']: pr for pr in prs}

                for pr_no in conflicting_prs:
                    pr = pr_metadata.get(pr_no, {})
                    issue_no = resolve_issue_from_pr(pr)

                    if issue_no is None:
                        _log(f"PR #{pr_no}: could not resolve issue number, skipping rebase", level="ERROR")
                        continue

                    if not worktree_exists(issue_no):
                        _log(f"PR #{pr_no}: worktree for issue #{issue_no} does not exist, skipping rebase")
                        continue

                    # Check worker availability (if bounded)
                    if num_workers > 0:
                        worker_id = get_free_worker(num_workers)
                        if worker_id is None:
                            _log(f"All {num_workers} workers busy, skipping PR rebase for now")
                            break

                        # Mark worker as busy before rebasing
                        write_worker_status(worker_id, 'BUSY', issue_no, None)
                        success, pid = rebase_worktree(pr_no)
                        if success:
                            write_worker_status(worker_id, 'BUSY', issue_no, pid)
                            _log(f"PR #{pr_no} rebase started, assigned to worker {worker_id}")
                        else:
                            write_worker_status(worker_id, 'FREE', None, None)
                            _log(f"Failed to rebase PR #{pr_no}", level="ERROR")
                    else:
                        # Unlimited workers mode
                        success, _ = rebase_worktree(pr_no)
                        if not success:
                            _log(f"Failed to rebase PR #{pr_no}", level="ERROR")
            except RuntimeError as e:
                _log(f"Error during PR discovery: {e}", level="ERROR")

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
    parser.add_argument(
        '--num-workers', type=int, default=5,
        help='Maximum concurrent workers (0 = unlimited). Default: 5'
    )
    args = parser.parse_args()

    try:
        period_seconds = parse_period(args.period)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    run_server(period_seconds, args.tg_token, args.tg_chat_id, args.num_workers)


if __name__ == '__main__':
    main()
