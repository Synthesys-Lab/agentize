"""Session utilities for hooks and lib modules.

Provides shared session directory path resolution used across multiple
hook and library files.
"""

import os


def session_dir(makedirs: bool = False) -> str:
    """Get session directory path using AGENTIZE_HOME fallback.

    Args:
        makedirs: If True, create the directory structure if it doesn't exist.
                  Defaults to False.

    Returns:
        String path to the session directory (.tmp/hooked-sessions under base).
    """
    base = os.getenv('AGENTIZE_HOME', '.')
    path = os.path.join(base, '.tmp', 'hooked-sessions')

    if makedirs:
        os.makedirs(path, exist_ok=True)

    return path
