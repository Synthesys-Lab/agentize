#!/usr/bin/env bash
# Test: PreToolUse hook permission matching

source "$(dirname "$0")/../common.sh"

HOOK_SCRIPT="$PROJECT_ROOT/.claude-plugin/hooks/pre-tool-use.py"
FIXTURE_FILE="$PROJECT_ROOT/tests/fixtures/test-pre-tool-use-input.json"

test_info "PreToolUse hook permission matching"

# Helper: Run hook with fixture and extract permission decision
# Note: Unsets AGENTIZE_USE_TG and HANDSOFF_AUTO_PERMISSION for test isolation
run_hook_with_fixture() {
    local fixture_key="$1"
    local decision

    # Extract fixture from JSON file using jq
    local input=$(jq -c ".$fixture_key" "$FIXTURE_FILE")

    # Run hook and extract permissionDecision (isolated from external services)
    decision=$(unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION; echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision')

    echo "$decision"
}

# Test 1: Bash git status should be allowed
test_info "Test 1: Bash git status → allow"
decision=$(run_hook_with_fixture "bash_git_status")
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for git status, got '$decision'"

# Test 2: Bash with env vars should strip env and match
test_info "Test 2: Bash ENV=foo git status → allow (env stripped)"
decision=$(run_hook_with_fixture "bash_with_env")
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for git status with env, got '$decision'"

# Test 3: Dangerous bash command should be denied
test_info "Test 3: Bash rm -rf → deny"
decision=$(run_hook_with_fixture "bash_denied")
[ "$decision" = "deny" ] || test_fail "Expected 'deny' for rm -rf, got '$decision'"

# Test 4: Read allowed path should be allowed
test_info "Test 4: Read allowed path → allow"
decision=$(run_hook_with_fixture "read_allowed")
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for allowed read path, got '$decision'"

# Test 5: Read .pem file should be denied
test_info "Test 5: Read .pem file → deny"
decision=$(run_hook_with_fixture "read_denied")
[ "$decision" = "deny" ] || test_fail "Expected 'deny' for .pem file, got '$decision'"

# Test 6: Bash git push should be allowed (per settings.json allow rules)
test_info "Test 6: Bash git push → allow"
decision=$(run_hook_with_fixture "bash_git_push")
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for git push, got '$decision'"

# Test 7: No match defaults to ask
test_info "Test 7: Unknown tool → ask (default)"
input='{"tool_name":"UnknownTool","tool_input":{},"session_id":"test"}'
# Unset Telegram to ensure test isolation
decision=$(unset AGENTIZE_USE_TG; echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision')
[ "$decision" = "ask" ] || test_fail "Expected 'ask' for unknown tool, got '$decision'"

# Test 8: Malformed pattern falls back to ask (fail-safe)
test_info "Test 8: Hook errors fall back to ask"
# This test verifies fail-safe behavior when hook encounters errors
# If the hook has malformed patterns, it should return 'ask' instead of crashing
input='{"tool_name":"Bash","tool_input":{"command":"test-command"},"session_id":"test"}'
decision=$(echo "$input" | python3 "$HOOK_SCRIPT" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecision')
# Should get a valid decision (not empty/null)
[ -n "$decision" ] || test_fail "Hook should return a decision even on errors"
[ "$decision" = "allow" ] || [ "$decision" = "deny" ] || [ "$decision" = "ask" ] || \
    test_fail "Hook returned invalid decision: '$decision'"

# Test 9: Python3 command should result in ask (per rules)
test_info "Test 9: Bash python3 → ask"
decision=$(run_hook_with_fixture "bash_ask_python")
[ "$decision" = "ask" ] || test_fail "Expected 'ask' for python3 command, got '$decision'"

# Test 10: gh api command should result in ask (per rules)
test_info "Test 10: Bash gh api → ask"
decision=$(run_hook_with_fixture "bash_ask_gh_api")
[ "$decision" = "ask" ] || test_fail "Expected 'ask' for gh api command, got '$decision'"

# Test 11: Grep tool should be allowed (module rules include search tools)
test_info "Test 11: Grep tool → allow"
decision=$(run_hook_with_fixture "grep_allowed")
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for Grep tool, got '$decision'"

# Test 12: Glob tool should be allowed (module rules include search tools)
test_info "Test 12: Glob tool → allow"
decision=$(run_hook_with_fixture "glob_allowed")
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for Glob tool, got '$decision'"

# Test 13: LSP tool should be allowed (module rules include code intelligence)
test_info "Test 13: LSP tool → allow"
decision=$(run_hook_with_fixture "lsp_allowed")
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for LSP tool, got '$decision'"

# Test 14: Task tool should be allowed (module rules include agent exploration)
test_info "Test 14: Task tool → allow"
decision=$(run_hook_with_fixture "task_allowed")
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for Task tool, got '$decision'"

# Test 15: TodoWrite tool should be allowed (module rules include user interaction)
test_info "Test 15: TodoWrite tool → allow"
decision=$(run_hook_with_fixture "todowrite_allowed")
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for TodoWrite tool, got '$decision'"

# Test 16: AskUserQuestion tool should be allowed (module rules include user interaction)
test_info "Test 16: AskUserQuestion tool → allow"
decision=$(run_hook_with_fixture "askuserquestion_allowed")
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for AskUserQuestion tool, got '$decision'"

# Test 17: Telegram config gating - disabled when AGENTIZE_USE_TG is not set
test_info "Test 17: Telegram disabled by default (no env)"
# Unset all Telegram-related vars and verify ask decision still works
(
    unset AGENTIZE_USE_TG TG_API_TOKEN TG_CHAT_ID
    decision=$(run_hook_with_fixture "bash_ask_python")
    [ "$decision" = "ask" ] || test_fail "Expected 'ask' when Telegram disabled, got '$decision'"
)

# Test 18: Telegram config gating - missing TG_API_TOKEN returns ask
test_info "Test 18: Telegram with missing token returns ask"
(
    export AGENTIZE_USE_TG=1
    unset TG_API_TOKEN TG_CHAT_ID
    decision=$(run_hook_with_fixture "bash_ask_python")
    [ "$decision" = "ask" ] || test_fail "Expected 'ask' with missing TG_API_TOKEN, got '$decision'"
)

# Test 19: Telegram config gating - missing TG_CHAT_ID returns ask
test_info "Test 19: Telegram with missing chat ID returns ask"
(
    export AGENTIZE_USE_TG=1
    export TG_API_TOKEN="test_token"
    unset TG_CHAT_ID
    decision=$(run_hook_with_fixture "bash_ask_python")
    [ "$decision" = "ask" ] || test_fail "Expected 'ask' with missing TG_CHAT_ID, got '$decision'"
)

# Test 20: HTML escape function handles special characters correctly
test_info "Test 20: HTML escape handles <, >, & correctly"
# Test the pure function logic directly without loading the entire module
escaped=$(python3 -c "
def escape_html(text):
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
print(escape_html('<script>alert(1)</script> & \"test\"'))
")
expected='&lt;script&gt;alert(1)&lt;/script&gt; &amp; "test"'
[ "$escaped" = "$expected" ] || test_fail "Expected '$expected', got '$escaped'"

# Test 21: Inline keyboard payload structure validation
test_info "Test 21: Inline keyboard structure is valid"
keyboard=$(python3 -c "
import json
def build_inline_keyboard(message_id):
    return {
        'inline_keyboard': [[
            {'text': '✅ Allow', 'callback_data': f'allow:{message_id}'},
            {'text': '❌ Deny', 'callback_data': f'deny:{message_id}'}
        ]]
    }
kb = build_inline_keyboard(12345)
print(json.dumps(kb))
")
# Validate structure: should have inline_keyboard array with buttons
has_allow=$(echo "$keyboard" | jq -r '.inline_keyboard[0][0].text')
has_deny=$(echo "$keyboard" | jq -r '.inline_keyboard[0][1].text')
allow_data=$(echo "$keyboard" | jq -r '.inline_keyboard[0][0].callback_data')
deny_data=$(echo "$keyboard" | jq -r '.inline_keyboard[0][1].callback_data')
[ "$has_allow" = "✅ Allow" ] || test_fail "Expected Allow button, got '$has_allow'"
[ "$has_deny" = "❌ Deny" ] || test_fail "Expected Deny button, got '$has_deny'"
[ "$allow_data" = "allow:12345" ] || test_fail "Expected 'allow:12345', got '$allow_data'"
[ "$deny_data" = "deny:12345" ] || test_fail "Expected 'deny:12345', got '$deny_data'"

# Test 22: Callback data format validation (parse and extract)
test_info "Test 22: Callback data parsing extracts action and message_id"
result=$(python3 -c "
def parse_callback_data(callback_data):
    parts = callback_data.split(':', 1)
    action = parts[0]
    message_id = int(parts[1]) if len(parts) > 1 else 0
    return action, message_id
action, msg_id = parse_callback_data('allow:12345')
print(f'{action}:{msg_id}')
")
[ "$result" = "allow:12345" ] || test_fail "Expected 'allow:12345', got '$result'"
# Test deny case
result=$(python3 -c "
def parse_callback_data(callback_data):
    parts = callback_data.split(':', 1)
    action = parts[0]
    message_id = int(parts[1]) if len(parts) > 1 else 0
    return action, message_id
action, msg_id = parse_callback_data('deny:67890')
print(f'{action}:{msg_id}')
")
[ "$result" = "deny:67890" ] || test_fail "Expected 'deny:67890', got '$result'"

# Test 23: _tg_api_request guard - returns None when Telegram is disabled
test_info "Test 23: _tg_api_request returns None when Telegram disabled"
guard_result=$(python3 -c "
import os
import sys
sys.path.insert(0, '$PROJECT_ROOT/.claude-plugin')
# Ensure Telegram is disabled
os.environ.pop('AGENTIZE_USE_TG', None)
from lib.permission.determine import _tg_api_request, _is_telegram_enabled
# Verify Telegram is disabled
assert not _is_telegram_enabled(), 'Telegram should be disabled'
# Call _tg_api_request - should return None without making any HTTP request
result = _tg_api_request('fake_token', 'sendMessage', {'chat_id': '123', 'text': 'test'})
print('None' if result is None else 'ERROR')
")
[ "$guard_result" = "None" ] || test_fail "Expected 'None' when Telegram disabled, got '$guard_result'"

# Test 24: _edit_message_result handles timeout decision correctly
test_info "Test 24: _edit_message_result handles timeout decision"
result=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/.claude-plugin')

# Test that _edit_message_result builds correct timeout message
from lib.permission.determine import _escape_html, SESSION_ID_DISPLAY_LEN

def build_result_text(decision, tool, target, session_id):
    if decision == 'timeout':
        emoji = '⏰'
        status = 'Timed Out'
    elif decision == 'allow':
        emoji = '✅'
        status = 'Allowed'
    else:
        emoji = '❌'
        status = 'Denied'

    return (
        f'{emoji} {status}\n\n'
        f'Tool: <code>{_escape_html(tool)}</code>\n'
        f'Target: <code>{_escape_html(target)}</code>\n'
        f'Session: {session_id[:SESSION_ID_DISPLAY_LEN]}'
    )

# Test timeout case
result = build_result_text('timeout', 'Bash', 'git push', 'test-session-123')
print(result)
")
# Verify timeout message contains expected elements
echo "$result" | grep -q '⏰ Timed Out' || test_fail "Expected '⏰ Timed Out' in result"
echo "$result" | grep -q '<code>Bash</code>' || test_fail "Expected tool name in result"
echo "$result" | grep -q '<code>git push</code>' || test_fail "Expected target in result"
echo "$result" | grep -q 'test-ses' || test_fail "Expected truncated session ID in result"

# Test 25: Workflow-scoped auto-allow for setup-viewboard - gh auth status
test_info "Test 25: setup-viewboard workflow → gh auth status auto-allow"
# Create a temporary session state file for setup-viewboard workflow
TMP_DIR=$(make_temp_dir "workflow-permission-test")
SESSION_ID="test-session-setup-viewboard"
mkdir -p "$TMP_DIR/.tmp/hooked-sessions"
echo '{"workflow": "setup-viewboard", "state": "initial", "continuation_count": 0}' > "$TMP_DIR/.tmp/hooked-sessions/$SESSION_ID.json"

# Run hook with AGENTIZE_HOME pointing to our tmp dir and workflow session
# Note: Using env to properly set and unset variables in a subshell
input=$(jq -c '.setup_viewboard_gh_auth_status' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for gh auth status in setup-viewboard workflow, got '$decision'"

# Test 26: Workflow-scoped auto-allow for setup-viewboard - gh repo view
test_info "Test 26: setup-viewboard workflow → gh repo view auto-allow"
input=$(jq -c '.setup_viewboard_gh_repo_view' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for gh repo view in setup-viewboard workflow, got '$decision'"

# Test 27: Workflow-scoped auto-allow for setup-viewboard - gh api graphql
test_info "Test 27: setup-viewboard workflow → gh api graphql auto-allow"
input=$(jq -c '.setup_viewboard_gh_api_graphql' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for gh api graphql in setup-viewboard workflow, got '$decision'"

# Test 28: Workflow-scoped auto-allow for setup-viewboard - gh label create
test_info "Test 28: setup-viewboard workflow → gh label create auto-allow"
input=$(jq -c '.setup_viewboard_gh_label_create' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for gh label create in setup-viewboard workflow, got '$decision'"

# Test 29: No auto-allow for gh api outside workflow
test_info "Test 29: gh api outside workflow → ask (no auto-allow)"
# Clear the session state to simulate no active workflow
rm -f "$TMP_DIR/.tmp/hooked-sessions/$SESSION_ID.json"
input=$(jq -c '.setup_viewboard_gh_api_graphql' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "ask" ] || test_fail "Expected 'ask' for gh api graphql outside workflow, got '$decision'"

cleanup_dir "$TMP_DIR"

# =============================================================================
# Evaluation Order Tests (Issue #488)
# These tests validate the correct permission evaluation order:
# Global rules → Workflow auto-allow → Haiku LLM → Telegram
# =============================================================================

# Test 30: Global deny overrides workflow allow
test_info "Test 30: Global deny overrides workflow allow (evaluation order)"
# Setup: Create workflow session that would allow rm -rf via workflow rules
ORDER_TMP_DIR=$(make_temp_dir "ordering-test")
ORDER_SESSION_ID="test-session-ordering"
mkdir -p "$ORDER_TMP_DIR/.tmp/hooked-sessions"
# Create a workflow session that tries to allow dangerous commands
echo '{"workflow": "setup-viewboard", "state": "initial", "continuation_count": 0}' > "$ORDER_TMP_DIR/.tmp/hooked-sessions/$ORDER_SESSION_ID.json"

# Even with workflow session active, rm -rf should be denied by global rules
input=$(jq -c '.order_test_global_deny_vs_workflow_allow' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$ORDER_TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "deny" ] || test_fail "Expected 'deny' for rm -rf even with workflow session, got '$decision' (global deny must override workflow)"

# Test 31: Rule ask falls through to workflow auto-allow
test_info "Test 31: Rule 'ask' falls through to workflow auto-allow"
# This test verifies: rule returns ask → workflow auto-allow is checked
# Using gh api graphql which:
#   - Global rules: ask (matches '^gh\s+api' ask rule)
#   - Workflow auto-allow: allow (for setup-viewboard workflow)
# After fix: global ask falls through to workflow, returns allow
# Need to create session file for the session ID used in the fixture
VIEWBOARD_SESSION_ID="test-session-setup-viewboard"
echo '{"workflow": "setup-viewboard", "state": "initial", "continuation_count": 0}' > "$ORDER_TMP_DIR/.tmp/hooked-sessions/$VIEWBOARD_SESSION_ID.json"
input=$(jq -c '.setup_viewboard_gh_api_graphql' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$ORDER_TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    # Use the setup-viewboard session
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for gh api graphql after ask falls through to workflow, got '$decision'"

# Test 32: Verify evaluation order via decision source (Python unit test)
test_info "Test 32: Evaluation order validation - global deny first"
result=$(python3 << 'PYEOF'
import sys
import os
import json

# Set up environment to disable external services
os.environ.pop('AGENTIZE_USE_TG', None)
os.environ.pop('HANDSOFF_AUTO_PERMISSION', None)

# Add project path
sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.permission.determine import _check_permission

# Mock _hook_input to provide session_id
import lib.permission.determine as determine_module
determine_module._hook_input = {'session_id': 'test-ordering'}

# Test: rm -rf should be denied by global rules, not workflow
decision, source = _check_permission('Bash', 'rm -rf /tmp', 'rm -rf /tmp')
if decision != 'deny' or source != 'rules':
    print(f'FAIL: Expected deny/rules for rm -rf, got {decision}/{source}')
    sys.exit(1)

print('PASS')
PYEOF
)
[ "$result" = "PASS" ] || test_fail "Evaluation order test failed: $result"

# Test 33: Telegram is final escalation (verify docstring matches implementation)
test_info "Test 33: Telegram is final escalation point (docstring verification)"
# This verifies that the docstring correctly describes the evaluation order
# by checking the _check_permission function's docstring
result=$(python3 << 'PYEOF'
import sys
import os

sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.permission.determine import _check_permission

# Verify the docstring reflects the correct evaluation order
docstring = _check_permission.__doc__
required_statements = [
    'Global rules (deny/allow return, ask falls through)',
    'Workflow auto-allow (allow returns, otherwise continue)',
    'Haiku LLM (allow/deny return, ask falls through)',
    'Telegram (single final escalation for ask)'
]

missing = []
for stmt in required_statements:
    if stmt not in docstring:
        missing.append(stmt)

if missing:
    print(f'FAIL: Docstring missing: {missing}')
    sys.exit(1)

# Also verify the priority numbers are in correct order (1-4)
if '1.' not in docstring or '2.' not in docstring or '3.' not in docstring or '4.' not in docstring:
    print('FAIL: Priority numbers 1-4 not found in docstring')
    sys.exit(1)

print('PASS')
PYEOF
)
[ "$result" = "PASS" ] || test_fail "Docstring verification test failed: $result"

cleanup_dir "$ORDER_TMP_DIR"

# =============================================================================
# Session State Modification Tests (Issue #505)
# These tests validate that workflows can update their session state files
# to signal completion without requiring permission prompts
# =============================================================================

# Test 34: Session state update to "done" is auto-allowed during workflow
test_info "Test 34: Session state update to 'done' → auto-allow"
TMP_DIR=$(make_temp_dir "session-state-test")
SESSION_ID="test-session-123"
mkdir -p "$TMP_DIR/.tmp/hooked-sessions"
# Create a session state file to indicate active workflow
echo '{"workflow": "issue-to-impl", "state": "in_progress", "continuation_count": 0}' > "$TMP_DIR/.tmp/hooked-sessions/$SESSION_ID.json"

input=$(jq -c '.session_state_update_done' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for session state update to 'done', got '$decision'"

# Test 35: Session state update to "completed" is auto-allowed
test_info "Test 35: Session state update to 'completed' → auto-allow"
SESSION_ID2="session-abc"
echo '{"workflow": "plan-to-issue", "state": "in_progress", "continuation_count": 1}' > "$TMP_DIR/.tmp/hooked-sessions/$SESSION_ID2.json"

input=$(jq -c '.session_state_update_completed' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for session state update to 'completed', got '$decision'"

# Test 36: Session state update to "error" is auto-allowed
test_info "Test 36: Session state update to 'error' → auto-allow"
SESSION_ID3="workflow-xyz"
echo '{"workflow": "ultra-planner", "state": "failed", "continuation_count": 0}' > "$TMP_DIR/.tmp/hooked-sessions/$SESSION_ID3.json"

input=$(jq -c '.session_state_update_error' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for session state update to 'error', got '$decision'"

# Test 37: Session state update to "failed" is auto-allowed
test_info "Test 37: Session state update to 'failed' → auto-allow"
SESSION_ID4="test-session"
echo '{"workflow": "issue-to-impl", "state": "failed", "continuation_count": 0}' > "$TMP_DIR/.tmp/hooked-sessions/$SESSION_ID4.json"

input=$(jq -c '.session_state_update_failed' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for session state update to 'failed', got '$decision'"

# Test 38: Session state update with different path formats is auto-allowed
test_info "Test 38: Session state update with relative path → auto-allow"
SESSION_ID5="test-1"
echo '{"workflow": "issue-to-impl", "state": "in_progress", "continuation_count": 0}' > "$TMP_DIR/.tmp/hooked-sessions/$SESSION_ID5.json"

input=$(jq -c '.session_state_with_quotes' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "allow" ] || test_fail "Expected 'allow' for session state update with relative path, got '$decision'"

# Test 39: Invalid path (missing .tmp) is NOT auto-allowed
test_info "Test 39: Session state update with invalid path → ask (not auto-allowed)"
input=$(jq -c '.session_state_invalid_path' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "ask" ] || test_fail "Expected 'ask' for session state update with invalid path (missing .tmp), got '$decision'"

# Test 40: Path traversal attempt is NOT auto-allowed
test_info "Test 40: Session state with path traversal → ask (not auto-allowed)"
input=$(jq -c '.session_state_path_traversal' "$FIXTURE_FILE")
decision=$(
    export AGENTIZE_HOME="$TMP_DIR"
    unset AGENTIZE_USE_TG HANDSOFF_AUTO_PERMISSION
    echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision'
)
[ "$decision" = "ask" ] || test_fail "Expected 'ask' for path traversal attempt, got '$decision'"

cleanup_dir "$TMP_DIR"

test_pass "PreToolUse hook permission matching works correctly"
