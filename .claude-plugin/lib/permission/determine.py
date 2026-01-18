"""Main permission determination logic.

This module provides the determine() function that evaluates tool permission
requests using rules, Haiku LLM, and Telegram approval backends.
"""

import os
import json
import re
import time
import datetime
import subprocess
import urllib.request
import urllib.error
from typing import Optional, Dict, Any, Tuple, List

from .rules import match_rule
from .strips import normalize_bash_command
from .parser import parse_hook_input, extract_target

# Import sibling modules from lib/
import sys
from pathlib import Path
_lib_dir = Path(__file__).resolve().parent.parent
if str(_lib_dir.parent) not in sys.path:
    sys.path.insert(0, str(_lib_dir.parent))
from lib.telegram_utils import escape_html as _shared_escape_html, telegram_request
from lib.logger import log_tool_decision, logger

# Constants
TELEGRAM_API_TIMEOUT_SEC = 10
HAIKU_SUBPROCESS_TIMEOUT_SEC = 30
TARGET_DISPLAY_MAX_LEN = 200
SESSION_ID_DISPLAY_LEN = 8
TELEGRAM_LONG_POLL_MAX_SEC = 30

# Module-level state for hook input (set by determine())
_hook_input: Dict[str, Any] = {}


def _ask_haiku_first(tool: str, target: str, workflow: str = 'unknown', session_id: str = 'unknown') -> str:
    """Ask Haiku LLM for permission decision.

    Args:
        tool: Tool name
        target: Raw target string for context
        workflow: Workflow name for logging
        session_id: Session ID for logging

    Returns:
        'allow', 'deny', or 'ask'
    """
    global _hook_input

    if os.getenv('HANDSOFF_AUTO_PERMISSION', '1').lower() not in ['1', 'true', 'on', 'enable']:
        log_tool_decision(session_id, '', tool, target, 'SKIP', workflow, 'haiku')
        return 'ask'

    transcript_path = _hook_input.get("transcript_path", "")

    # Read last line from JSONL transcript
    try:
        with open(transcript_path, 'r') as f:
            transcript = f.readlines()[-1]
    except Exception as e:
        log_tool_decision(session_id, '', tool, target, f'ERROR:{str(e)}', workflow, 'error')
        return 'ask'

    prompt = f'''Evaluate this Claude Code tool call for automatic permission in hands-off mode.

Tool: {tool}
Target: {target}

Risk categories:
- allow: Read-only operations, file search, git status, safe builds, test runs,
  or auto coder linters and formmatters
- deny: Destructive ops (rm -rf, git reset --hard), secrets access (e.g. env to see all env vars),
  sudo, force push to non-dev branches, overriding anything outside this repo or tmp
- ask: Unclear intent, external API writes, untrusted script execution, something between ---
  not that dangerous as direct denial, not as safe as direct allow

Context (last transcript entry):
{transcript}

Reply with allow, deny, or ask as the first word. Brief reasoning is optional.'''

    try:
        result = subprocess.check_output(
            ['claude', '--model', 'haiku', '-p'],
            input=prompt,
            text=True,
            timeout=HAIKU_SUBPROCESS_TIMEOUT_SEC
        )
        full_response = result.strip().lower()

        # Check first word using startswith (handles "allow.", "allow because...", etc.)
        if full_response.startswith('allow'):
            log_tool_decision(session_id, transcript, tool, target, 'allow', workflow, 'haiku')
            return 'allow'
        elif full_response.startswith('deny'):
            log_tool_decision(session_id, transcript, tool, target, 'deny', workflow, 'haiku')
            return 'deny'
        elif full_response.startswith('ask'):
            log_tool_decision(session_id, transcript, tool, target, 'ask', workflow, 'haiku')
            return 'ask'
        else:
            log_tool_decision(session_id, transcript, tool, target, f'ERROR:invalid_output:{full_response[:50]}', workflow, 'haiku')
            return 'ask'
    except subprocess.TimeoutExpired as e:
        log_tool_decision(session_id, transcript, tool, target, f'ERROR:timeout', workflow, 'haiku')
        return 'ask'
    except subprocess.CalledProcessError as e:
        log_tool_decision(session_id, transcript, tool, target, f'ERROR:process', workflow, 'haiku')
        return 'ask'
    except Exception as e:
        log_tool_decision(session_id, transcript, tool, target, f'ERROR:subprocess', workflow, 'haiku')
        return 'ask'


def _is_telegram_enabled() -> bool:
    """Check if Telegram approval is enabled and configured."""
    use_tg = os.getenv('AGENTIZE_USE_TG', '0').lower()
    return use_tg in ['1', 'true', 'on']


def _get_telegram_config() -> Optional[Dict[str, Any]]:
    """Get Telegram configuration from environment.

    Returns:
        dict with keys: token, chat_id, timeout, poll_interval, allowed_user_ids
        or None if required config is missing
    """
    token = os.getenv('TG_API_TOKEN', '')
    chat_id = os.getenv('TG_CHAT_ID', '')

    if not token or not chat_id:
        return None

    timeout = int(os.getenv('TG_APPROVAL_TIMEOUT_SEC', '60'))
    poll_interval = int(os.getenv('TG_POLL_INTERVAL_SEC', '5'))

    # Parse allowed user IDs (optional)
    allowed_ids_str = os.getenv('TG_ALLOWED_USER_IDS', '')
    allowed_user_ids: List[int] = []
    if allowed_ids_str:
        allowed_user_ids = [int(uid.strip()) for uid in allowed_ids_str.split(',') if uid.strip()]

    return {
        'token': token,
        'chat_id': chat_id,
        'timeout': timeout,
        'poll_interval': poll_interval,
        'allowed_user_ids': allowed_user_ids
    }


def _tg_api_request(token: str, method: str, payload: Optional[Dict[str, Any]] = None, session_id: str = 'unknown', workflow: str = 'unknown') -> Optional[Dict[str, Any]]:
    """Make a request to Telegram Bot API.

    Args:
        token: Bot API token
        method: API method (e.g., 'sendMessage', 'getUpdates')
        payload: Request payload dict (optional)
        session_id: Session ID for logging (optional)
        workflow: Workflow name for logging

    Returns:
        dict: API response or None on error/disabled
    """
    # Safety guard: return immediately if Telegram is disabled
    if not _is_telegram_enabled():
        return None

    return telegram_request(
        token, method, payload,
        timeout_sec=TELEGRAM_API_TIMEOUT_SEC,
        on_error=lambda e: log_tool_decision(session_id, '', 'Telegram', method, f'ERROR:api', workflow, 'telegram')
    )


def _escape_html(text: str) -> str:
    """Escape special HTML characters for Telegram HTML parse mode.

    Telegram HTML mode requires escaping: < > &
    """
    return _shared_escape_html(text)


def _build_inline_keyboard(message_id: int) -> Dict[str, Any]:
    """Build inline keyboard markup with Allow/Deny buttons.

    Args:
        message_id: The message ID to include in callback_data for correlation

    Returns:
        InlineKeyboardMarkup dict for Telegram API
    """
    return {
        'inline_keyboard': [[
            {'text': '✅ Allow', 'callback_data': f'allow:{message_id}'},
            {'text': '❌ Deny', 'callback_data': f'deny:{message_id}'}
        ]]
    }


def _parse_callback_data(callback_data: str) -> Tuple[str, int]:
    """Parse callback_data from inline keyboard button press.

    Args:
        callback_data: String in format "action:message_id" (e.g., "allow:12345")

    Returns:
        Tuple of (action, message_id). Returns (action, 0) on parse errors.
    """
    parts = callback_data.split(':', 1)
    action = parts[0]
    try:
        message_id = int(parts[1]) if len(parts) > 1 else 0
    except ValueError:
        message_id = 0
    return action, message_id


def _handle_callback_query(token: str, callback_query: Dict[str, Any], expected_message_id: int,
                           session_id: str = 'unknown') -> Optional[str]:
    """Process a callback query from inline keyboard button press.

    Args:
        token: Bot API token
        callback_query: The callback_query object from Telegram update
        expected_message_id: The message_id we're waiting for (for correlation)
        session_id: Session ID for logging

    Returns:
        'allow', 'deny', or None if this callback doesn't match our request
    """
    callback_data = callback_query.get('data', '')
    action, msg_id = _parse_callback_data(callback_data)

    # Verify message_id matches (ignore callbacks from other requests)
    if msg_id != expected_message_id:
        return None

    callback_id = callback_query.get('id', '')

    # Acknowledge the callback to stop the loading spinner
    _tg_api_request(token, 'answerCallbackQuery', {
        'callback_query_id': callback_id,
        'text': f"{'✅ Allowed' if action == 'allow' else '❌ Denied'}"
    }, session_id)

    return action if action in ['allow', 'deny'] else None


def _edit_message_result(token: str, chat_id: str, message_id: int, tool: str,
                         target: str, decision: str, session_id: str = 'unknown') -> None:
    """Edit the original approval message to show the decision result.

    Preserves original tool/target info and updates status line.

    Args:
        token: Bot API token
        chat_id: Chat ID where the message was sent
        message_id: ID of the message to edit
        tool: Tool name for display
        target: Target string for display (truncated)
        decision: 'allow', 'deny', or 'timeout'
        session_id: Session ID for logging
    """
    if decision == 'timeout':
        emoji = '⏰'
        status = 'Timed Out'
    elif decision == 'allow':
        emoji = '✅'
        status = 'Allowed'
    else:
        emoji = '❌'
        status = 'Denied'

    # Preserve original message content with updated status
    result_text = (
        f"{emoji} {status}\n\n"
        f"Tool: <code>{_escape_html(tool)}</code>\n"
        f"Target: <code>{_escape_html(target)}</code>\n"
        f"Session: {session_id[:SESSION_ID_DISPLAY_LEN]}"
    )

    _tg_api_request(token, 'editMessageText', {
        'chat_id': chat_id,
        'message_id': message_id,
        'text': result_text,
        'parse_mode': 'HTML'
    }, session_id)


def _telegram_approval_decision(tool: str, target: str, session_id: str, raw_target: str, workflow: str = 'unknown') -> Optional[str]:
    """Request approval via Telegram for an 'ask' decision.

    Args:
        tool: Tool name
        target: Normalized target (for display)
        session_id: Current session ID
        raw_target: Original target (for display)
        workflow: Workflow name for logging

    Returns:
        'allow', 'deny', or None (on timeout/error, caller should return 'ask')
    """
    if not _is_telegram_enabled():
        return None

    config = _get_telegram_config()
    if not config:
        log_tool_decision(session_id, '', tool, raw_target, 'ERROR:config_missing', workflow, 'telegram')
        return None

    token: str = config['token']
    chat_id: str = config['chat_id']
    timeout: int = config['timeout']
    poll_interval: int = config['poll_interval']
    allowed_user_ids: List[int] = config['allowed_user_ids']

    # Get current update_id offset to ignore old messages
    updates_resp = _tg_api_request(token, 'getUpdates', {'limit': 1, 'offset': -1}, session_id, workflow)
    if updates_resp and updates_resp.get('ok') and updates_resp.get('result'):
        last_update = updates_resp['result'][-1]
        update_offset = last_update.get('update_id', 0) + 1
    else:
        update_offset = 0

    # Send approval request message with HTML formatting and inline keyboard
    truncated_target = raw_target[:TARGET_DISPLAY_MAX_LEN]
    message_text = (
        f"🔧 Tool Approval Request\n\n"
        f"Tool: <code>{_escape_html(tool)}</code>\n"
        f"Target: <code>{_escape_html(truncated_target)}</code>\n"
        f"Session: {session_id[:SESSION_ID_DISPLAY_LEN]}"
    )

    send_resp = _tg_api_request(token, 'sendMessage', {
        'chat_id': chat_id,
        'text': message_text,
        'parse_mode': 'HTML',
        'reply_markup': _build_inline_keyboard(0)  # Placeholder, will update with actual message_id
    }, session_id, workflow)

    if not send_resp or not send_resp.get('ok'):
        log_tool_decision(session_id, '', tool, raw_target, 'ERROR:send_failed', workflow, 'telegram')
        return None

    message_id = send_resp.get('result', {}).get('message_id', 0)
    log_tool_decision(session_id, '', tool, raw_target, f'sent:msg_id={message_id}', workflow, 'telegram')

    # Update the message with correct callback_data containing the actual message_id
    if message_id:
        _tg_api_request(token, 'editMessageReplyMarkup', {
            'chat_id': chat_id,
            'message_id': message_id,
            'reply_markup': _build_inline_keyboard(message_id)
        }, session_id, workflow)

    # Poll for response (both callback_query and text commands)
    start_time = time.monotonic()
    while (time.monotonic() - start_time) < timeout:
        updates_resp = _tg_api_request(token, 'getUpdates', {
            'offset': update_offset,
            'timeout': min(poll_interval, TELEGRAM_LONG_POLL_MAX_SEC)
        }, session_id, workflow)

        if not updates_resp or not updates_resp.get('ok'):
            time.sleep(poll_interval)
            continue

        for update in updates_resp.get('result', []):
            update_offset = update.get('update_id', 0) + 1

            # Check for callback_query (inline button press)
            callback_query = update.get('callback_query')
            if callback_query:
                from_user = callback_query.get('from', {})
                user_id = from_user.get('id')

                # Check if response is from allowed user (if configured)
                if allowed_user_ids and user_id not in allowed_user_ids:
                    continue

                decision = _handle_callback_query(token, callback_query, message_id, session_id)
                if decision:
                    log_tool_decision(session_id, '', tool, raw_target,
                                      decision, workflow, 'telegram')
                    # Edit the original message to show result
                    _edit_message_result(token, chat_id, message_id, tool, truncated_target, decision, session_id)
                    return decision

            # Check for text message (backward compatibility with /allow /deny commands)
            msg = update.get('message', {})
            text = msg.get('text', '').strip().lower()
            from_user = msg.get('from', {})
            user_id = from_user.get('id')

            # Check if response is from allowed user (if configured)
            if allowed_user_ids and user_id not in allowed_user_ids:
                continue

            # Check for /allow or /deny commands
            if text == '/allow' or text.startswith('/allow '):
                log_tool_decision(session_id, '', tool, raw_target, 'allow', workflow, 'telegram')
                # Send confirmation reply
                _tg_api_request(token, 'sendMessage', {
                    'chat_id': chat_id,
                    'text': f"✅ Allowed: <code>{_escape_html(tool)}</code>",
                    'parse_mode': 'HTML',
                    'reply_to_message_id': msg.get('message_id')
                }, session_id, workflow)
                # Edit the original message to show result
                _edit_message_result(token, chat_id, message_id, tool, truncated_target, 'allow', session_id)
                return 'allow'
            elif text == '/deny' or text.startswith('/deny '):
                log_tool_decision(session_id, '', tool, raw_target, 'deny', workflow, 'telegram')
                # Send confirmation reply
                _tg_api_request(token, 'sendMessage', {
                    'chat_id': chat_id,
                    'text': f"❌ Denied: <code>{_escape_html(tool)}</code>",
                    'parse_mode': 'HTML',
                    'reply_to_message_id': msg.get('message_id')
                }, session_id, workflow)
                # Edit the original message to show result
                _edit_message_result(token, chat_id, message_id, tool, truncated_target, 'deny', session_id)
                return 'deny'

    # Timeout reached
    log_tool_decision(session_id, '', tool, raw_target, 'ERROR:timeout', workflow, 'telegram')
    _edit_message_result(token, chat_id, message_id, tool, truncated_target, 'timeout', session_id)
    return None


def _check_permission(tool: str, target: str, raw_target: str, workflow: str = 'unknown') -> Tuple[str, str]:
    """Check permission for tool usage.

    Returns: (decision, source) where decision is 'allow'/'deny'/'ask'
    and source is 'rules', 'haiku', 'telegram', 'workflow', or 'error'

    Priority:
    1. Global rules (deny/allow return, ask falls through)
    2. Workflow auto-allow (allow returns, otherwise continue)
    3. Haiku LLM (allow/deny return, ask falls through)
    4. Telegram (single final escalation for ask)
    """
    global _hook_input
    session_id = _hook_input.get('session_id', 'unknown')

    try:
        # Stage 1: Global rules first (deny/allow return, ask falls through)
        rule_result = match_rule(tool, target)
        if rule_result:
            decision, source = rule_result
            if decision in ('deny', 'allow'):
                return rule_result
            # 'ask' falls through to workflow

        # Stage 2: Workflow auto-allow (after global rules)
        workflow_decision = _check_workflow_auto_allow(session_id, tool, target)
        if workflow_decision in ('deny', 'allow'):
            return (workflow_decision, 'workflow')

        # Stage 3: Haiku LLM evaluation (use raw_target for context)
        haiku_decision = _ask_haiku_first(tool, raw_target, workflow, session_id)
        if haiku_decision in ('deny', 'allow'):
            return (haiku_decision, 'haiku')

        # Stage 4: Telegram - single final escalation for all 'ask' outcomes
        tg_decision = _telegram_approval_decision(tool, target, session_id, raw_target, workflow)
        if tg_decision:
            return (tg_decision, 'telegram')

        return ('ask', 'fallback')
    except Exception:
        # Error recovery: try Haiku, then Telegram, then fallback to ask
        try:
            haiku_decision = _ask_haiku_first(tool, raw_target, workflow, session_id)
            if haiku_decision in ('deny', 'allow'):
                return (haiku_decision, 'haiku')
            # Haiku returned ask, try Telegram
            tg_decision = _telegram_approval_decision(tool, target, session_id, raw_target, workflow)
            if tg_decision:
                return (tg_decision, 'telegram')
            return ('ask', 'fallback')
        except Exception:
            # If even Haiku fails, try Telegram as last resort
            tg_decision = _telegram_approval_decision(tool, target, session_id, raw_target, workflow)
            if tg_decision:
                return (tg_decision, 'telegram')
            return ('ask', 'error')


def _session_dir() -> str:
    """Get session directory path using AGENTIZE_HOME fallback."""
    base = os.getenv('AGENTIZE_HOME', '.')
    return os.path.join(base, '.tmp', 'hooked-sessions')


def _log_debug_info(session: str, workflow: str, tool: str, raw_target: str,
                    permission_decision: str, decision_source: str) -> None:
    """Log debug information to unified permission.txt when HANDSOFF_DEBUG is enabled."""
    if os.getenv('HANDSOFF_MODE', '1').lower() not in ['1', 'true', 'on', 'enable']:
        return
    # Note: log_tool_decision already checks HANDSOFF_DEBUG, so we don't need to check again
    log_tool_decision(session, '', tool, raw_target, permission_decision, workflow, decision_source)


def _detect_workflow(session: str) -> str:
    """Detect workflow state from session state file."""
    state_file = os.path.join(_session_dir(), f'{session}.json')
    if not os.path.exists(state_file):
        return 'unknown'

    try:
        with open(state_file, 'r') as f:
            state = json.load(f)
            workflow_type = state.get('workflow', '')
            if workflow_type == 'ultra-planner':
                return 'plan'
            elif workflow_type == 'issue-to-impl':
                return 'impl'
            elif workflow_type == 'plan-to-issue':
                return 'plan'
            elif workflow_type == 'setup-viewboard':
                return 'setup-viewboard'
    except (json.JSONDecodeError, Exception):
        pass

    return 'unknown'


def _get_workflow_type(session: str) -> str:
    """Get raw workflow type from session state file.

    Returns the workflow value directly without mapping to short names.
    Used for workflow-scoped permission checks.
    """
    state_file = os.path.join(_session_dir(), f'{session}.json')
    if not os.path.exists(state_file):
        return ''

    try:
        with open(state_file, 'r') as f:
            state = json.load(f)
            return state.get('workflow', '')
    except (json.JSONDecodeError, Exception):
        pass

    return ''


# Workflow-scoped auto-allow patterns for setup-viewboard
# These commands are known safe operations within the setup-viewboard workflow
_SETUP_VIEWBOARD_ALLOW_PATTERNS = [
    r'^gh auth status',                     # Authentication verification
    r'^gh repo view --json owner',          # Repository owner lookup
    r'^gh api graphql',                     # Project creation and configuration
    r'^gh label create --force',            # Label creation
]

# Session state modification patterns (allowed for all workflows)
# These patterns allow workflows to update their session state files to signal completion
# Pattern: jq '.state = "done"' file.json > file.json.tmp && mv file.json.tmp file.json
_SESSION_STATE_ALLOW_PATTERNS = [
    r'^jq\s+[\'"]\s*\.\s*state\s*=\s*[\'"](done|completed|error|failed)[\'"]\s*[\'"]?\s+.*\.tmp/hooked-sessions/[a-zA-Z0-9_-]+\.json\s*>\s*.*\.tmp/hooked-sessions/[a-zA-Z0-9_-]+\.json\.tmp\s*&&\s*mv\s+.*\.tmp/hooked-sessions/[a-zA-Z0-9_-]+\.json\.tmp\s+.*\.tmp/hooked-sessions/[a-zA-Z0-9_-]+\.json$',
]


def _check_workflow_auto_allow(session: str, tool: str, target: str) -> Optional[str]:
    """Check if a tool should be auto-allowed based on active workflow.

    Args:
        session: Session ID
        tool: Tool name
        target: Normalized target (command for Bash)

    Returns:
        'allow' if workflow permits, None otherwise
    """
    workflow = _get_workflow_type(session)

    # Session state modifications allowed for ALL workflows during active sessions
    if tool == 'Bash':
        for pattern in _SESSION_STATE_ALLOW_PATTERNS:
            if re.match(pattern, target):
                return 'allow'

    # Setup-viewboard specific patterns
    if workflow == 'setup-viewboard' and tool == 'Bash':
        for pattern in _SETUP_VIEWBOARD_ALLOW_PATTERNS:
            if re.match(pattern, target):
                return 'allow'

    return None


def determine(stdin_data: str) -> dict:
    """Determine permission for a tool use request.

    This is the main entry point for the permission module.

    Args:
        stdin_data: Raw JSON string from Claude Code PreToolUse hook

    Returns:
        dict with hookSpecificOutput containing permissionDecision
    """
    global _hook_input

    # Parse input
    _hook_input = parse_hook_input(stdin_data)

    tool = _hook_input['tool_name']
    session = _hook_input['session_id']
    tool_input = _hook_input.get('tool_input', {})


    # Extract target
    target = extract_target(tool, tool_input)

    # Keep raw_target for logging, normalize target for permission checking
    raw_target = target
    if tool == 'Bash':
        target = normalize_bash_command(target)

    logger(session, f'PreToolUse hook determine.tool: {tool}')
    logger(session, f'PreToolUse hook determine.target: {target}')

    # Detect workflow for logging
    workflow = _detect_workflow(session)

    # Check permission
    permission_decision, decision_source = _check_permission(tool, target, raw_target, workflow)

    # Debug logging
    _log_debug_info(session, workflow, tool, raw_target, permission_decision, decision_source)

    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": permission_decision
        }
    }
