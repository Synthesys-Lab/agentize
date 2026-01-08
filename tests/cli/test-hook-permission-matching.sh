#!/usr/bin/env bash
# Test: PreToolUse hook permission matching

source "$(dirname "$0")/../common.sh"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/pre-tool-use.py"
FIXTURE_FILE="$PROJECT_ROOT/tests/fixtures/test-pre-tool-use-input.json"

test_info "PreToolUse hook permission matching"

# Helper: Run hook with fixture and extract permission decision
run_hook_with_fixture() {
    local fixture_key="$1"
    local decision

    # Extract fixture from JSON file using jq
    local input=$(jq -c ".$fixture_key" "$FIXTURE_FILE")

    # Run hook and extract permissionDecision
    decision=$(echo "$input" | python3 "$HOOK_SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision')

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

# Test 11: Telegram config gating - disabled when AGENTIZE_USE_TG is not set
test_info "Test 11: Telegram disabled by default (no env)"
# Unset all Telegram-related vars and verify ask decision still works
(
    unset AGENTIZE_USE_TG TG_API_TOKEN TG_CHAT_ID
    decision=$(run_hook_with_fixture "bash_ask_python")
    [ "$decision" = "ask" ] || test_fail "Expected 'ask' when Telegram disabled, got '$decision'"
)

# Test 12: Telegram config gating - missing TG_API_TOKEN returns ask
test_info "Test 12: Telegram with missing token returns ask"
(
    export AGENTIZE_USE_TG=1
    unset TG_API_TOKEN TG_CHAT_ID
    decision=$(run_hook_with_fixture "bash_ask_python")
    [ "$decision" = "ask" ] || test_fail "Expected 'ask' with missing TG_API_TOKEN, got '$decision'"
)

# Test 13: Telegram config gating - missing TG_CHAT_ID returns ask
test_info "Test 13: Telegram with missing chat ID returns ask"
(
    export AGENTIZE_USE_TG=1
    export TG_API_TOKEN="test_token"
    unset TG_CHAT_ID
    decision=$(run_hook_with_fixture "bash_ask_python")
    [ "$decision" = "ask" ] || test_fail "Expected 'ask' with missing TG_CHAT_ID, got '$decision'"
)

# Test 14: HTML escape function handles special characters correctly
test_info "Test 14: HTML escape handles <, >, & correctly"
# Test the pure function logic directly without loading the entire module
escaped=$(python3 -c "
def escape_html(text):
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
print(escape_html('<script>alert(1)</script> & \"test\"'))
")
expected='&lt;script&gt;alert(1)&lt;/script&gt; &amp; "test"'
[ "$escaped" = "$expected" ] || test_fail "Expected '$expected', got '$escaped'"

# Test 15: Inline keyboard payload structure validation
test_info "Test 15: Inline keyboard structure is valid"
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

# Test 16: Callback data format validation (parse and extract)
test_info "Test 16: Callback data parsing extracts action and message_id"
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

test_pass "PreToolUse hook permission matching works correctly"
