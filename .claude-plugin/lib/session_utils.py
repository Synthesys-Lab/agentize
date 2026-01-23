"""Session utilities for hooks and lib modules.

Provides shared session directory path resolution, handsoff mode checks,
AGENTIZE_HOME resolution, and issue index file management used across
multiple hook and library files.
"""

import json
import os


def get_agentize_home() -> str:
    """Get AGENTIZE_HOME path for agentize repository root resolution.

    Derives the path in the following order:
    1. AGENTIZE_HOME environment variable (if set)
    2. Derive from session_utils.py location (.claude-plugin/lib/session_utils.py → repo root)

    Returns:
        Path to agentize repository root

    Note:
        Does not validate the path - caller should handle errors if expected files are missing.
        Uses os.path.realpath to resolve symlinks (e.g., .cursor/hooks/lib -> .claude-plugin/lib).
    """
    # First, check environment variable
    env_home = os.getenv('AGENTIZE_HOME', '').strip()
    if env_home:
        return env_home

    # Derive from session_utils.py location: .claude-plugin/lib/session_utils.py → ../../
    # Use realpath to resolve symlinks (e.g., .cursor/hooks/lib -> .claude-plugin/lib)
    module_dir = os.path.dirname(os.path.realpath(__file__))
    repo_root = os.path.dirname(os.path.dirname(module_dir))
    return repo_root


def is_handsoff_enabled() -> bool:
    """Check if handsoff mode is enabled via environment variable.

    Returns:
        True if handsoff mode is enabled (default), False if disabled.
        Returns False only when HANDSOFF_MODE is set to 0, false, off, or disable
        (case-insensitive). All other values including unset default to enabled.
    """
    handsoff = os.getenv('HANDSOFF_MODE', '1')
    return handsoff.lower() not in ['0', 'false', 'off', 'disable']


def write_issue_index(
    session_id: str,
    issue_no: int | str,
    workflow: str,
    sess_dir: str | None = None
) -> str:
    """Write an issue index file for reverse lookup from issue number to session.

    Args:
        session_id: The session ID to index.
        issue_no: The issue number (int or string).
        workflow: The workflow name (e.g., "issue-to-impl").
        sess_dir: Optional session directory path. If None, uses session_dir(makedirs=True).

    Returns:
        The path to the created index file.
    """
    if sess_dir is None:
        sess_dir = session_dir(makedirs=True)

    by_issue_dir = os.path.join(sess_dir, 'by-issue')
    os.makedirs(by_issue_dir, exist_ok=True)

    issue_index_file = os.path.join(by_issue_dir, f'{issue_no}.json')
    with open(issue_index_file, 'w') as f:
        index_data = {'session_id': session_id, 'workflow': workflow}
        json.dump(index_data, f)

    return issue_index_file


def session_dir(makedirs: bool = False) -> str:
    """Get session directory path using AGENTIZE_HOME fallback.

    Args:
        makedirs: If True, create the directory structure if it doesn't exist.
                  Defaults to False.

    Returns:
        String path to the session directory (.tmp/hooked-sessions under base).
    """
    base = get_agentize_home()
    path = os.path.join(base, '.tmp', 'hooked-sessions')

    if makedirs:
        os.makedirs(path, exist_ok=True)

    return path
