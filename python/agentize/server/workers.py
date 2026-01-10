"""Worktree spawn/rebase and worker status file management for the server module."""

import os
import re
from pathlib import Path

from agentize.shell import run_shell_function
from agentize.server.log import _log


# Worker status file management
DEFAULT_WORKERS_DIR = '.tmp/workers'


def _parse_pid_from_output(stdout: str) -> int | None:
    """Parse PID from wt command output.

    Looks for lines containing 'PID' and extracts the number.
    """
    for line in stdout.splitlines():
        if 'PID' in line:
            match = re.search(r'PID[:\s]+(\d+)', line)
            if match:
                return int(match.group(1))
    return None


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

    return True, _parse_pid_from_output(result.stdout)


def rebase_worktree(pr_no: int) -> tuple[bool, int | None]:
    """Rebase a PR's worktree using wt rebase command.

    Returns:
        Tuple of (success, pid). pid is None if rebase failed.
    """
    _log(f"Rebasing worktree for PR #{pr_no}...")
    result = run_shell_function(f'wt rebase {pr_no} --headless', capture_output=True)
    if result.returncode != 0:
        return False, None

    return True, _parse_pid_from_output(result.stdout)


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
    # Import here to avoid circular imports
    from agentize.server.notify import send_telegram_message, _format_worker_completion_message
    from agentize.server.session import _get_session_state_for_issue, _remove_issue_index

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
