import os
import datetime

from lib.session_utils import session_dir, get_agentize_home


def _tmp_dir():
    """Get tmp directory path using get_agentize_home()."""
    base = get_agentize_home()
    return os.path.join(base, '.tmp')


def _is_debug_enabled() -> bool:
    """Check if debug logging is enabled via YAML config with env override.

    Precedence: HANDSOFF_DEBUG env > handsoff.debug YAML > False (default)
    """
    from lib.local_config import get_local_value, coerce_bool
    return get_local_value('handsoff.debug', 'HANDSOFF_DEBUG', False, coerce_bool)


def logger(sid, msg):
    if not _is_debug_enabled():
        return
    tmp_dir = _tmp_dir()
    os.makedirs(tmp_dir, exist_ok=True)
    log_path = os.path.join(tmp_dir, 'hook-debug.log')
    with open(log_path, 'a') as log_file:
        time = datetime.datetime.now().isoformat()
        log_file.write(f"[{time}] [{sid}] {msg}\n")


def log_tool_decision(session, context, tool, target, decision, workflow='unknown', source='error'):
    # Log permission decisions to unified permission.txt file
    if not _is_debug_enabled():
        return
    sess_dir = session_dir(makedirs=True)
    time = datetime.datetime.now().isoformat()
    log_path = os.path.join(sess_dir, 'permission.txt')
    with open(log_path, 'a') as f:
        f.write(f'[{time}] [{session}] [{workflow}] [{source}] [{decision}] {tool} | {target}\n')
