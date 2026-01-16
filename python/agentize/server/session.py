"""Session state file lookups for the server module."""

import json
import os
from pathlib import Path


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


def set_pr_number_for_issue(issue_no: int, pr_number: int, session_dir: Path | None = None) -> bool:
    """Best-effort persistence of PR number into session state.

    Args:
        issue_no: GitHub issue number
        pr_number: PR number to store
        session_dir: Path to hooked-sessions directory (uses AGENTIZE_HOME if None)

    Returns:
        True if successfully written, False otherwise (missing index or session file)
    """
    if session_dir is None:
        session_dir = _resolve_session_dir()

    # Get session_id from issue index
    session_id = _load_issue_index(issue_no, session_dir)
    if session_id is None:
        return False

    # Load existing session state
    session_file = session_dir / f'{session_id}.json'
    if not session_file.exists():
        return False

    try:
        with open(session_file) as f:
            state = json.load(f)

        # Add pr_number to state
        state['pr_number'] = pr_number

        # Write back atomically
        tmp_file = session_dir / f'{session_id}.json.tmp'
        with open(tmp_file, 'w') as f:
            json.dump(state, f)
        tmp_file.rename(session_file)

        return True
    except (json.JSONDecodeError, OSError):
        return False
