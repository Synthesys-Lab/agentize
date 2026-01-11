"""Worktree spawn/rebase and worker status file management for the server module."""

import os
import re
import subprocess
import time
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


def _check_issue_has_label(issue_no: int, label: str) -> bool:
    """Check if issue has a specific label.

    Args:
        issue_no: GitHub issue number
        label: Label name to check for

    Returns:
        True if the issue has the label, False otherwise.
    """
    result = subprocess.run(
        ['gh', 'issue', 'view', str(issue_no), '--json', 'labels', '--jq', '.labels[].name'],
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        return False
    return label in result.stdout.strip().split('\n')


def _cleanup_refinement(issue_no: int) -> None:
    """Clean up after refinement: remove agentize:refine label.

    Args:
        issue_no: GitHub issue number
    """
    # Remove agentize:refine label
    subprocess.run(
        ['gh', 'issue', 'edit', str(issue_no), '--remove-label', 'agentize:refine'],
        capture_output=True,
        text=True
    )
    _log(f"Refinement cleanup for issue #{issue_no}: removed agentize:refine label")


def _cleanup_feat_request(issue_no: int) -> None:
    """Clean up after feat-request planning: remove agentize:feat-request label.

    Args:
        issue_no: GitHub issue number
    """
    # Remove agentize:feat-request label
    subprocess.run(
        ['gh', 'issue', 'edit', str(issue_no), '--remove-label', 'agentize:feat-request'],
        capture_output=True,
        text=True
    )
    _log(f"Feat-request cleanup for issue #{issue_no}: removed agentize:feat-request label")


def spawn_refinement(issue_no: int) -> tuple[bool, int | None]:
    """Spawn a refinement session for the given issue.

    Creates worktree if not exists, sets status to Refining, and spawns
    claude with /ultra-planner --refine headlessly.

    Returns:
        Tuple of (success, pid). pid is None if spawn failed.
    """
    # Create worktree if not exists (reuse if exists)
    if not worktree_exists(issue_no):
        result = run_shell_function(f'wt spawn {issue_no} --no-agent --headless', capture_output=True)
        if result.returncode != 0:
            _log(f"Failed to create worktree for issue #{issue_no}", level="ERROR")
            return False, None

    # Get worktree path
    result = run_shell_function(f'wt pathto {issue_no}', capture_output=True)
    if result.returncode != 0:
        _log(f"Failed to get worktree path for issue #{issue_no}", level="ERROR")
        return False, None
    worktree_path = result.stdout.strip()

    # Set status to "Refining" (best-effort claim)
    run_shell_function(
        f'wt_claim_issue_status {issue_no} "{worktree_path}" Refining',
        capture_output=True
    )

    # Create log directory and file
    log_dir = Path(os.getenv('AGENTIZE_HOME', '.')) / '.tmp' / 'logs'
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f'refine-{issue_no}-{int(time.time())}.log'

    # Spawn Claude with /ultra-planner --refine
    # Note: Popen duplicates the file descriptor, so the child process inherits it
    # and continues writing even after the 'with' block exits
    with open(log_file, 'w') as f:
        proc = subprocess.Popen(
            ['claude', '--print', f'/ultra-planner --refine {issue_no}'],
            cwd=worktree_path,
            stdin=subprocess.DEVNULL,
            stdout=f,
            stderr=subprocess.STDOUT
        )

    _log(f"Spawned refinement for issue #{issue_no}, PID: {proc.pid}, log: {log_file}")
    return True, proc.pid


def spawn_feat_request(issue_no: int) -> tuple[bool, int | None]:
    """Spawn a feat-request planning session for the given issue.

    Creates worktree if not exists, and spawns claude with /ultra-planner --from-issue headlessly.

    Returns:
        Tuple of (success, pid). pid is None if spawn failed.
    """
    # Create worktree if not exists (reuse if exists)
    if not worktree_exists(issue_no):
        result = run_shell_function(f'wt spawn {issue_no} --no-agent --headless', capture_output=True)
        if result.returncode != 0:
            _log(f"Failed to create worktree for feat-request issue #{issue_no}", level="ERROR")
            return False, None

    # Get worktree path
    result = run_shell_function(f'wt pathto {issue_no}', capture_output=True)
    if result.returncode != 0:
        _log(f"Failed to get worktree path for issue #{issue_no}", level="ERROR")
        return False, None
    worktree_path = result.stdout.strip()

    # Create log directory and file
    log_dir = Path(os.getenv('AGENTIZE_HOME', '.')) / '.tmp' / 'logs'
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f'feat-request-{issue_no}-{int(time.time())}.log'

    # Spawn Claude with /ultra-planner --from-issue
    with open(log_file, 'w') as f:
        proc = subprocess.Popen(
            ['claude', '--print', f'/ultra-planner --from-issue {issue_no}'],
            cwd=worktree_path,
            stdin=subprocess.DEVNULL,
            stdout=f,
            stderr=subprocess.STDOUT
        )

    _log(f"Spawned feat-request planning for issue #{issue_no}, PID: {proc.pid}, log: {log_file}")
    return True, proc.pid


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
                    # Check if this was a refinement (has agentize:refine label)
                    if _check_issue_has_label(issue_no, 'agentize:refine'):
                        _cleanup_refinement(issue_no)

                    # Check if this was a feat-request (has agentize:feat-request label)
                    if _check_issue_has_label(issue_no, 'agentize:feat-request'):
                        _cleanup_feat_request(issue_no)

                    issue_url = f"https://github.com/{repo_slug}/issues/{issue_no}" if repo_slug else None
                    msg = _format_worker_completion_message(issue_no, i, issue_url)
                    if send_telegram_message(tg_token, tg_chat_id, msg):
                        _log(f"Sent completion notification for issue #{issue_no}")
                        # Remove issue index to prevent duplicate notifications
                        _remove_issue_index(issue_no, session_dir)

            write_worker_status(i, 'FREE', None, None, workers_dir)
