#!/usr/bin/env bash
# Test: session lookup via issue index for completion notifications

source "$(dirname "$0")/../common.sh"

test_info "server session lookup helpers"

TMP_DIR=$(make_temp_dir "session-lookup-test")
trap "cleanup_dir '$TMP_DIR'" EXIT

# Test 1: _resolve_session_dir uses AGENTIZE_HOME
output=$(AGENTIZE_HOME="$TMP_DIR" PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _resolve_session_dir

result = _resolve_session_dir()
assert str(result).endswith('.tmp/hooked-sessions'), f'Expected hooked-sessions path, got {result}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_resolve_session_dir: $output"
fi

# Test 2: _load_issue_index returns session_id when file exists
mkdir -p "$TMP_DIR/.tmp/hooked-sessions/by-issue"
echo '{"session_id": "abc123", "workflow": "issue-to-impl"}' > "$TMP_DIR/.tmp/hooked-sessions/by-issue/42.json"

output=$(AGENTIZE_HOME="$TMP_DIR" PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _resolve_session_dir, _load_issue_index

session_dir = _resolve_session_dir()
session_id = _load_issue_index(42, session_dir)
assert session_id == 'abc123', f'Expected abc123, got {session_id}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_load_issue_index found: $output"
fi

# Test 3: _load_issue_index returns None when file missing
output=$(AGENTIZE_HOME="$TMP_DIR" PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _resolve_session_dir, _load_issue_index

session_dir = _resolve_session_dir()
session_id = _load_issue_index(999, session_dir)
assert session_id is None, f'Expected None for missing issue, got {session_id}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_load_issue_index missing: $output"
fi

# Test 4: _load_session_state loads session JSON
echo '{"workflow": "issue-to-impl", "state": "done", "issue_no": 42}' > "$TMP_DIR/.tmp/hooked-sessions/abc123.json"

output=$(AGENTIZE_HOME="$TMP_DIR" PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _resolve_session_dir, _load_session_state

session_dir = _resolve_session_dir()
state = _load_session_state('abc123', session_dir)
assert state is not None, 'Expected state dict'
assert state['state'] == 'done', f'Expected done, got {state}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_load_session_state: $output"
fi

# Test 5: _get_session_state_for_issue combines lookup
output=$(AGENTIZE_HOME="$TMP_DIR" PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _resolve_session_dir, _get_session_state_for_issue

session_dir = _resolve_session_dir()
state = _get_session_state_for_issue(42, session_dir)
assert state is not None, 'Expected combined lookup to work'
assert state['state'] == 'done', f'Expected done state, got {state}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_get_session_state_for_issue: $output"
fi

# Test 6: _get_session_state_for_issue returns None for missing
output=$(AGENTIZE_HOME="$TMP_DIR" PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import _resolve_session_dir, _get_session_state_for_issue

session_dir = _resolve_session_dir()
state = _get_session_state_for_issue(888, session_dir)
assert state is None, f'Expected None for missing issue, got {state}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "_get_session_state_for_issue missing: $output"
fi

test_pass "server session lookup helpers work correctly"
