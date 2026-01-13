import os
import datetime


def _session_dir():
    """Get session directory path using AGENTIZE_HOME fallback."""
    base = os.getenv('AGENTIZE_HOME', '.')
    return os.path.join(base, '.tmp', 'hooked-sessions')


def _tmp_dir():
    """Get tmp directory path using AGENTIZE_HOME fallback."""
    base = os.getenv('AGENTIZE_HOME', '.')
    return os.path.join(base, '.tmp')


def logger(sid, msg):
    if os.getenv('HANDSOFF_DEBUG', '0').lower() in ['0', 'false', 'off', 'disable']:
        return
    tmp_dir = _tmp_dir()
    os.makedirs(tmp_dir, exist_ok=True)
    log_path = os.path.join(tmp_dir, 'hook-debug.log')
    with open(log_path, 'a') as log_file:
        time = datetime.datetime.now().isoformat()
        log_file.write(f"[{time}] [{sid}] {msg}\n")


def log_tool_decision(session, context, tool, target, decision):
    # Log all Haiku decisions and errors to tool-haiku-determined.txt
    if os.getenv('HANDSOFF_DEBUG', '0').lower() in ['0', 'false', 'off', 'disable']:
        return
    session_dir = _session_dir()
    os.makedirs(session_dir, exist_ok=True)
    time = datetime.datetime.now().isoformat()
    log_path = os.path.join(session_dir, 'tool-haiku-determined.txt')
    with open(log_path, 'a') as f:
        f.write(f'[{time}] [{session}] {tool} | {target} => {decision}\n')