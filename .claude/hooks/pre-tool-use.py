#!/usr/bin/env python3

import sys
import json
import os
import datetime
import re
import subprocess
import time
import urllib.request
import urllib.error
from typing import Optional, Dict, Any, Tuple, List
from logger import log_tool_decision

# This hook logs tools used in HANDSOFF_MODE and enforces permission rules.

# Constants
TELEGRAM_API_TIMEOUT_SEC = 10
HAIKU_SUBPROCESS_TIMEOUT_SEC = 30
TARGET_DISPLAY_MAX_LEN = 200
SESSION_ID_DISPLAY_LEN = 8
TELEGRAM_LONG_POLL_MAX_SEC = 30

# Permission rules: (tool_name, regex_pattern)
# Priority: deny → ask → allow (first match wins)
PERMISSION_RULES = {
    'allow': [
        # Skills
        ('Skill', r'^open-pr'),
        ('Skill', r'^open-issue'),
        ('Skill', r'^fork-dev-branch'),
        ('Skill', r'^commit-msg'),
        ('Skill', r'^review-standard'),
        ('Skill', r'^external-consensus'),
        ('Skill', r'^milestone'),
        ('Skill', r'^code-review'),
        ('Skill', r'^pull-request'),

        # WebSearch and WebFetch
        ('WebSearch', r'.*'),
        ('WebFetch', r'.*'),

        # File operations
        ('Write', r'.*'),
        ('Edit', r'.*'),
        ('Read', r'^/.*'),  # Allow reading any absolute path (deny rules filter secrets)

        # Bash - File operations
        ('Bash', r'^chmod \+x'),
        ('Bash', r'^test -f'),
        ('Bash', r'^test -d'),
        ('Bash', r'^date'),
        ('Bash', r'^echo'),
        ('Bash', r'^cat'),
        ('Bash', r'^head'),
        ('Bash', r'^tail'),
        ('Bash', r'^find'),
        ('Bash', r'^ls'),
        ('Bash', r'^wc'),
        ('Bash', r'^grep'),
        ('Bash', r'^rg'),
        ('Bash', r'^tree'),
        ('Bash', r'^tee'),
        ('Bash', r'^awk'),
        ('Bash', r'^xargs ls'),
        ('Bash', r'^xargs wc'),

        # Bash - Build tools
        ('Bash', r'^ninja'),
        ('Bash', r'^cmake'),
        ('Bash', r'^mkdir'),
        ('Bash', r'^make (all|build|check|lint|setup|test)'),

        # Bash - Test execution (project-neutral convention)
        ('Bash', r'^(\./)?tests/.*\.sh'),

        # Bash - Environment
        ('Bash', r'^module load'),

        # Bash - Git read operations
        ('Bash', r'^git (status|diff|log|show|rev-parse)'),

        # Bash - Git rebase to merge
        ('Bash', r'^git fetch (origin|upstream)'),
        ('Bash', r'^git rebase (origin|upstream) (main|master)'),
        ('Bash', r'^git rebase --continue'),

        # Bash - GitHub read operations
        ('Bash', r'^gh search'),
        ('Bash', r'^gh run (view|list)'),
        ('Bash', r'^gh pr (view|checks|list|diff|create)'),
        ('Bash', r'^gh issue (list|view|create)'),
        ('Bash', r'^gh label list'),
        ('Bash', r'^gh project (list|field-list|view|item-list)'),

        # Bash - External consensus script
        ('Bash', r'^\.claude/skills/external-consensus/scripts/external-consensus\.sh'),

        # Bash - Git write operations (more aggressive)
        ('Bash', r'^git add'),
        ('Bash', r'^git push'),
        ('Bash', r'^git commit'),

    ],
    'deny': [
        # Destructive operations
        ('Bash', r'^cd'),
        ('Bash', r'^rm -rf'),
        ('Bash', r'^sudo'),
        ('Bash', r'^git reset'),
        ('Bash', r'^git restore'),

        # Secret files
        ('Read', r'^\.env$'),
        ('Read', r'^\.env\.'),
        ('Read', r'.*/licenses/.*'),
        ('Read', r'.*/secrets?/.*'),
        ('Read', r'.*/config/credentials\.json$'),
        ('Read', r'/.*\.key$'),
        ('Read', r'.*\.pem$'),
    ],
    'ask': [
        # General commands
        ('Bash', r'^python3'),
        ('Bash', r'^test(?!\s+-[fd])'),  # test without -f or -d flags

        # GitHub write operations
        ('Bash', r'^gh api'),
        ('Bash', r'^gh project item-edit'),
    ]
}

def strip_env_vars(command: str) -> str:
    """Strip leading ENV=value pairs from bash commands."""
    # Match one or more ENV=value patterns at the start
    env_pattern = re.compile(r'^(\w+=\S+\s+)+')
    return env_pattern.sub('', command)

def strip_shell_prefixes(command: str) -> str:
    """Strip leading shell option prefixes from bash commands.

    Common prefixes like 'set -x && ' or 'set -e && ' are debugging/safety
    options that don't change command semantics for permission purposes.
    """
    # Match patterns like: set -x && , set -e && , set -o pipefail &&
    prefix_pattern = re.compile(r'^(set\s+-[exo]\s+[a-z]*\s*&&\s*)+', re.IGNORECASE)
    return prefix_pattern.sub('', command)

def ask_haiku_first(tool: str, target: str) -> str:
    global hook_input

    if os.getenv('HANDSOFF_AUTO_PERMISSION', '0').lower() not in ['1', 'true', 'on', 'enable']:
        log_tool_decision(hook_input.get('session_id', 'unknown'), '', tool, target, 'SKIP_HAIKU')
        return 'ask'

    transcript_path = hook_input.get("transcript_path", "")

    # Read last line from JSONL transcript
    try:
        with open(transcript_path, 'r') as f:
            transcript = f.readlines()[-1]
    except Exception as e:
        log_tool_decision(hook_input.get('session_id', 'unknown'), '', tool, target, f'ERROR transcript: {str(e)}')
        return 'ask'

    prompt = f'''Evaluate this Claude Code tool call for automatic permission in hands-off mode.

Tool: {tool}
Target: {target}

Risk categories:
- allow: Read-only operations, file search, git status, safe builds, test runs
- deny: Destructive ops (rm -rf, git reset --hard), secrets access, sudo, force push
- ask: Unclear intent, external API writes, untrusted script execution

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

        # Log the full Haiku response for debugging
        log_tool_decision(hook_input['session_id'], transcript, tool, target, f'HAIKU: {full_response}')

        # Check first word using startswith (handles "allow.", "allow because...", etc.)
        if full_response.startswith('allow'):
            return 'allow'
        elif full_response.startswith('deny'):
            return 'deny'
        elif full_response.startswith('ask'):
            return 'ask'
        else:
            log_tool_decision(hook_input['session_id'], transcript, tool, target, f'ERROR invalid_output: {full_response[:50]}')
            return 'ask'
    except subprocess.TimeoutExpired as e:
        log_tool_decision(hook_input['session_id'], transcript, tool, target, f'ERROR timeout: {str(e)}')
        return 'ask'
    except subprocess.CalledProcessError as e:
        log_tool_decision(hook_input['session_id'], transcript, tool, target, f'ERROR process: returncode={e.returncode} stderr={e.stderr}')
        return 'ask'
    except Exception as e:
        log_tool_decision(hook_input['session_id'], transcript, tool, target, f'ERROR subprocess: {str(e)}')
        return 'ask'

def normalize_bash_command(command: str) -> str:
    """Normalize bash command by stripping env vars and shell prefixes."""
    command = strip_env_vars(command)
    command = strip_shell_prefixes(command)
    return command


# Telegram approval integration

def escape_html(text: str) -> str:
    """Escape special HTML characters for Telegram HTML parse mode.

    Telegram HTML mode requires escaping: < > &
    """
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def build_inline_keyboard(message_id: int) -> Dict[str, Any]:
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


def parse_callback_data(callback_data: str) -> Tuple[str, int]:
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


def handle_callback_query(token: str, callback_query: Dict[str, Any], expected_message_id: int,
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
    action, msg_id = parse_callback_data(callback_data)

    # Verify message_id matches (ignore callbacks from other requests)
    if msg_id != expected_message_id:
        return None

    callback_id = callback_query.get('id', '')

    # Acknowledge the callback to stop the loading spinner
    tg_api_request(token, 'answerCallbackQuery', {
        'callback_query_id': callback_id,
        'text': f"{'✅ Allowed' if action == 'allow' else '❌ Denied'}"
    }, session_id)

    return action if action in ['allow', 'deny'] else None


def edit_message_result(token: str, chat_id: str, message_id: int, tool: str,
                        decision: str, session_id: str = 'unknown') -> None:
    """Edit the original approval message to show the decision result.

    Args:
        token: Bot API token
        chat_id: Chat ID where the message was sent
        message_id: ID of the message to edit
        tool: Tool name for display
        decision: 'allow' or 'deny'
        session_id: Session ID for logging
    """
    emoji = '✅' if decision == 'allow' else '❌'
    result_text = f"{emoji} {'Allowed' if decision == 'allow' else 'Denied'}: {escape_html(tool)}"

    tg_api_request(token, 'editMessageText', {
        'chat_id': chat_id,
        'message_id': message_id,
        'text': result_text,
        'parse_mode': 'HTML'
    }, session_id)


def is_telegram_enabled() -> bool:
    """Check if Telegram approval is enabled and configured."""
    use_tg = os.getenv('AGENTIZE_USE_TG', '0').lower()
    return use_tg in ['1', 'true', 'on']


def get_telegram_config() -> Optional[Dict[str, Any]]:
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


def tg_api_request(token: str, method: str, payload: Optional[Dict[str, Any]] = None, session_id: str = 'unknown') -> Optional[Dict[str, Any]]:
    """Make a request to Telegram Bot API.

    Args:
        token: Bot API token
        method: API method (e.g., 'sendMessage', 'getUpdates')
        payload: Request payload dict (optional)
        session_id: Session ID for logging (optional)

    Returns:
        dict: API response or None on error
    """
    url = f'https://api.telegram.org/bot{token}/{method}'
    try:
        if payload:
            data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
        else:
            req = urllib.request.Request(url)

        with urllib.request.urlopen(req, timeout=TELEGRAM_API_TIMEOUT_SEC) as response:
            return json.loads(response.read().decode('utf-8'))
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, TimeoutError) as e:
        log_tool_decision(session_id, '', 'Telegram', method, f'API_ERROR: {str(e)[:100]}')
        return None


def telegram_approval_decision(tool: str, target: str, session_id: str, raw_target: str) -> Optional[str]:
    """Request approval via Telegram for an 'ask' decision.

    Args:
        tool: Tool name
        target: Normalized target (for display)
        session_id: Current session ID
        raw_target: Original target (for display)

    Returns:
        'allow', 'deny', or None (on timeout/error, caller should return 'ask')
    """
    if not is_telegram_enabled():
        return None

    config = get_telegram_config()
    if not config:
        log_tool_decision(session_id, '', tool, raw_target, 'TG_CONFIG_MISSING')
        return None

    token: str = config['token']
    chat_id: str = config['chat_id']
    timeout: int = config['timeout']
    poll_interval: int = config['poll_interval']
    allowed_user_ids: List[int] = config['allowed_user_ids']

    # Get current update_id offset to ignore old messages
    updates_resp = tg_api_request(token, 'getUpdates', {'limit': 1, 'offset': -1}, session_id)
    if updates_resp and updates_resp.get('ok') and updates_resp.get('result'):
        last_update = updates_resp['result'][-1]
        update_offset = last_update.get('update_id', 0) + 1
    else:
        update_offset = 0

    # Send approval request message with HTML formatting and inline keyboard
    truncated_target = raw_target[:TARGET_DISPLAY_MAX_LEN]
    message_text = (
        f"🔧 Tool Approval Request\n\n"
        f"Tool: <code>{escape_html(tool)}</code>\n"
        f"Target: <code>{escape_html(truncated_target)}</code>\n"
        f"Session: {session_id[:SESSION_ID_DISPLAY_LEN]}\n\n"
        f"<i>Or reply /allow or /deny</i>"
    )

    send_resp = tg_api_request(token, 'sendMessage', {
        'chat_id': chat_id,
        'text': message_text,
        'parse_mode': 'HTML',
        'reply_markup': build_inline_keyboard(0)  # Placeholder, will update with actual message_id
    }, session_id)

    if not send_resp or not send_resp.get('ok'):
        log_tool_decision(session_id, '', tool, raw_target, 'TG_SEND_FAILED')
        return None

    message_id = send_resp.get('result', {}).get('message_id', 0)
    log_tool_decision(session_id, '', tool, raw_target, f'TG_SENT message_id={message_id}')

    # Update the message with correct callback_data containing the actual message_id
    if message_id:
        tg_api_request(token, 'editMessageReplyMarkup', {
            'chat_id': chat_id,
            'message_id': message_id,
            'reply_markup': build_inline_keyboard(message_id)
        }, session_id)

    # Poll for response (both callback_query and text commands)
    start_time = time.monotonic()
    while (time.monotonic() - start_time) < timeout:
        updates_resp = tg_api_request(token, 'getUpdates', {
            'offset': update_offset,
            'timeout': min(poll_interval, TELEGRAM_LONG_POLL_MAX_SEC)
        }, session_id)

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

                decision = handle_callback_query(token, callback_query, message_id, session_id)
                if decision:
                    log_tool_decision(session_id, '', tool, raw_target,
                                      f'TG_{decision.upper()} user_id={user_id} via=button')
                    # Edit the original message to show result
                    edit_message_result(token, chat_id, message_id, tool, decision, session_id)
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
                log_tool_decision(session_id, '', tool, raw_target,
                                  f'TG_ALLOW user_id={user_id} via=text')
                # Send confirmation reply
                tg_api_request(token, 'sendMessage', {
                    'chat_id': chat_id,
                    'text': f"✅ Allowed: <code>{escape_html(tool)}</code>",
                    'parse_mode': 'HTML',
                    'reply_to_message_id': msg.get('message_id')
                }, session_id)
                # Edit the original message to show result
                edit_message_result(token, chat_id, message_id, tool, 'allow', session_id)
                return 'allow'
            elif text == '/deny' or text.startswith('/deny '):
                log_tool_decision(session_id, '', tool, raw_target,
                                  f'TG_DENY user_id={user_id} via=text')
                # Send confirmation reply
                tg_api_request(token, 'sendMessage', {
                    'chat_id': chat_id,
                    'text': f"❌ Denied: <code>{escape_html(tool)}</code>",
                    'parse_mode': 'HTML',
                    'reply_to_message_id': msg.get('message_id')
                }, session_id)
                # Edit the original message to show result
                edit_message_result(token, chat_id, message_id, tool, 'deny', session_id)
                return 'deny'

    # Timeout reached
    log_tool_decision(session_id, '', tool, raw_target, f'TG_TIMEOUT after {timeout}s')
    tg_api_request(token, 'sendMessage', {
        'chat_id': chat_id,
        'text': f"⏰ Timeout: No response for <code>{escape_html(tool)}</code>, falling back to local prompt",
        'parse_mode': 'HTML',
        'reply_to_message_id': message_id
    }, session_id)
    return None

def verify_force_push_to_own_branch(command: str) -> Optional[str]:
    """Check if force push targets the current branch (issue-* branches only).

    Returns 'allow' if pushing to own issue branch, 'deny' otherwise.
    This prevents accidentally/maliciously force pushing to others' branches.
    """
    # Match: git push --force/--force-with-lease/-f origin/upstream issue-*
    match = re.match(r'^git push (--force-with-lease|--force|-f) (origin|upstream) (issue-\S+)', command)
    if not match:
        return None  # Not a force push to issue branch

    target_branch = match.group(3)

    try:
        current_branch = subprocess.check_output(
            ['git', 'branch', '--show-current'],
            text=True,
            timeout=5
        ).strip()

        # Extract issue number from both branches (issue-42 or issue-42-title)
        target_issue = re.match(r'^issue-(\d+)', target_branch)
        current_issue = re.match(r'^issue-(\d+)', current_branch)

        if target_issue and current_issue:
            if target_issue.group(1) == current_issue.group(1):
                return 'allow'
            else:
                return 'deny'  # Pushing to different issue's branch

        return 'deny'  # Current branch is not an issue branch
    except Exception:
        return None  # Can't verify, let other rules handle it

def check_permission(tool: str, target: str, raw_target: str) -> Tuple[str, str]:
    """
    Check permission for tool usage against PERMISSION_RULES.
    Returns: (decision, source) where decision is 'allow'/'deny'/'ask' and source is 'rules', 'haiku', or 'telegram'
    Priority: deny → ask → allow (first match wins)
    Default: ask Haiku if no match or error, then try Telegram if enabled

    Args:
        tool: Tool name
        target: Normalized target (for rule matching)
        raw_target: Original target (for logging/Haiku context)
    """
    session_id = hook_input.get('session_id', 'unknown')

    try:
        # Special check: force push to issue branches requires current branch verification
        if tool == 'Bash':
            force_push_result = verify_force_push_to_own_branch(target)
            if force_push_result is not None:
                return (force_push_result, 'force-push-verify')

        # Check rules in priority order: deny → ask → allow
        for decision in ['deny', 'ask', 'allow']:
            for rule_tool, pattern in PERMISSION_RULES.get(decision, []):
                if rule_tool == tool:
                    try:
                        if re.search(pattern, target):
                            # For 'ask' decisions, try Telegram approval if enabled
                            if decision == 'ask':
                                tg_decision = telegram_approval_decision(tool, target, session_id, raw_target)
                                if tg_decision:
                                    return (tg_decision, 'telegram')
                            return (decision, 'rules')
                    except re.error:
                        # Malformed pattern, fail safe to 'ask'
                        continue

        # No match, ask Haiku (use raw_target for context)
        haiku_decision = ask_haiku_first(tool, raw_target)

        # If Haiku returns 'ask', try Telegram approval
        if haiku_decision == 'ask':
            tg_decision = telegram_approval_decision(tool, target, session_id, raw_target)
            if tg_decision:
                return (tg_decision, 'telegram')

        return (haiku_decision, 'haiku')
    except Exception as e:
        # Any error, ask Haiku as fallback
        try:
            haiku_decision = ask_haiku_first(tool, raw_target)
            # If Haiku returns 'ask', try Telegram approval
            if haiku_decision == 'ask':
                tg_decision = telegram_approval_decision(tool, target, session_id, raw_target)
                if tg_decision:
                    return (tg_decision, 'telegram')
            return (haiku_decision, 'haiku')
        except Exception:
            # If even Haiku fails, try Telegram as last resort
            tg_decision = telegram_approval_decision(tool, target, session_id, raw_target)
            if tg_decision:
                return (tg_decision, 'telegram')
            return ('ask', 'error')

hook_input = json.load(sys.stdin)

tool = hook_input['tool_name']
session = hook_input['session_id']
tool_input = hook_input.get('tool_input', {})

# Extract relevant object/target from tool_input
target = ''
if tool in ['Read', 'Write', 'Edit', 'NotebookEdit']:
    target = tool_input.get('file_path', '')
elif tool == 'Bash':
    target = tool_input.get('command', '')
elif tool == 'Grep':
    pattern = tool_input.get('pattern', '')
    path = tool_input.get('path', '')
    target = f'pattern={pattern}' + (f' path={path}' if path else '')
elif tool == 'Glob':
    pattern = tool_input.get('pattern', '')
    path = tool_input.get('path', '')
    target = f'pattern={pattern}' + (f' path={path}' if path else '')
elif tool == 'Task':
    subagent = tool_input.get('subagent_type', '')
    desc = tool_input.get('description', '')
    target = f'subagent={subagent} desc={desc}'
elif tool == 'Skill':
    skill = tool_input.get('skill', '')
    args = tool_input.get('args', '')
    target = skill + (f' {args}' if args else '')
elif tool == 'WebFetch':
    url = tool_input.get('url', '')
    target = url
elif tool == 'WebSearch':
    query = tool_input.get('query', '')
    target = f'query={query}'
elif tool == 'LSP':
    op = tool_input.get('operation', '')
    file_path = tool_input.get('filePath', '')
    line = tool_input.get('line', '')
    target = f'op={op} file={file_path}:{line}'
elif tool == 'AskUserQuestion':
    questions = tool_input.get('questions', [])
    if questions:
        headers = [q.get('header', '') for q in questions]
        target = f'questions={",".join(headers)}'
elif tool == 'TodoWrite':
    todos = tool_input.get('todos', [])
    target = f'todos={len(todos)}'
else:
    # For other tools, try to get a representative field
    target = str(tool_input)[:100]

# Keep raw_target for logging, normalize target for permission checking
raw_target = target
if tool == 'Bash':
    target = normalize_bash_command(target)

# Check permission
permission_decision, decision_source = check_permission(tool, target, raw_target)

if os.getenv('HANDSOFF_MODE', '0').lower() in ['1', 'true', 'on', 'enable'] and \
   os.getenv('HANDSOFF_DEBUG', '0').lower() in ['1', 'true', 'on', 'enable']:
    os.makedirs('.tmp', exist_ok=True)
    os.makedirs('.tmp/hooked-sessions', exist_ok=True)

    # Detect workflow state from session state file
    workflow = 'unknown'
    state_file = f'.tmp/hooked-sessions/{session}.json'
    if os.path.exists(state_file):
        try:
            with open(state_file, 'r') as f:
                state = json.load(f)
                workflow_type = state.get('workflow', '')
                if workflow_type == 'ultra-planner':
                    workflow = 'plan'
                elif workflow_type == 'issue-to-impl':
                    workflow = 'impl'
        except (json.JSONDecodeError, Exception):
            pass

    # Log tool usage - separate files for rules vs haiku vs telegram decisions
    # Use raw_target for logging to preserve original command
    time = datetime.datetime.now().isoformat()
    if decision_source == 'rules' and permission_decision == 'allow':
        # Automatically approved tools go to tool-used.txt
        with open('.tmp/hooked-sessions/tool-used.txt', 'a') as f:
            f.write(f'[{time}] [{session}] [{workflow}] {tool} | {raw_target}\n')
    elif decision_source == 'haiku':
        # Haiku-determined tools go to their own file
        with open('.tmp/hooked-sessions/tool-haiku-determined.txt', 'a') as f:
            f.write(f'[{time}] [{session}] [{workflow}] [{permission_decision}] {tool} | {raw_target}\n')
    elif decision_source == 'telegram':
        # Telegram-determined tools go to their own file
        with open('.tmp/hooked-sessions/tool-telegram-determined.txt', 'a') as f:
            f.write(f'[{time}] [{session}] [{workflow}] [{permission_decision}] {tool} | {raw_target}\n')

output = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": permission_decision
    }
}
print(json.dumps(output))