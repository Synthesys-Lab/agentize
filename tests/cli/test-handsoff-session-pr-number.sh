#!/usr/bin/env bash
# Test: session helper for persisting pr_number in session state

source "$(dirname "$0")/../common.sh"

test_info "session pr_number helper"

TMP_DIR=$(make_temp_dir "session-pr-number-test")
trap "cleanup_dir '$TMP_DIR'" EXIT

# Test 1: set_pr_number_for_issue writes pr_number to session state
mkdir -p "$TMP_DIR/.tmp/hooked-sessions/by-issue"
echo '{"session_id": "sess123", "workflow": "issue-to-impl"}' > "$TMP_DIR/.tmp/hooked-sessions/by-issue/42.json"
echo '{"workflow": "issue-to-impl", "state": "done", "issue_no": 42}' > "$TMP_DIR/.tmp/hooked-sessions/sess123.json"

output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import set_pr_number_for_issue
from pathlib import Path
import json

session_dir = Path('$TMP_DIR/.tmp/hooked-sessions')
result = set_pr_number_for_issue(42, 123, session_dir)
assert result is True, f'Expected True, got {result}'

# Verify pr_number was written
with open(session_dir / 'sess123.json') as f:
    state = json.load(f)
    assert state.get('pr_number') == 123, f'Expected pr_number=123, got {state}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "set_pr_number_for_issue write: $output"
fi

# Test 2: set_pr_number_for_issue returns False when issue index is missing
output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import set_pr_number_for_issue
from pathlib import Path

session_dir = Path('$TMP_DIR/.tmp/hooked-sessions')
result = set_pr_number_for_issue(999, 123, session_dir)  # Non-existent issue
assert result is False, f'Expected False for missing issue, got {result}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "set_pr_number_for_issue missing issue: $output"
fi

# Test 3: set_pr_number_for_issue returns False when session file is missing
mkdir -p "$TMP_DIR/.tmp/hooked-sessions/by-issue"
echo '{"session_id": "nonexistent", "workflow": "issue-to-impl"}' > "$TMP_DIR/.tmp/hooked-sessions/by-issue/888.json"

output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import set_pr_number_for_issue
from pathlib import Path

session_dir = Path('$TMP_DIR/.tmp/hooked-sessions')
result = set_pr_number_for_issue(888, 123, session_dir)  # Session file doesn't exist
assert result is False, f'Expected False for missing session file, got {result}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "set_pr_number_for_issue missing session: $output"
fi

# Test 4: set_pr_number_for_issue preserves existing state fields
echo '{"session_id": "sess456", "workflow": "issue-to-impl"}' > "$TMP_DIR/.tmp/hooked-sessions/by-issue/100.json"
echo '{"workflow": "issue-to-impl", "state": "in_progress", "issue_no": 100, "continuation_count": 3}' > "$TMP_DIR/.tmp/hooked-sessions/sess456.json"

output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.__main__ import set_pr_number_for_issue
from pathlib import Path
import json

session_dir = Path('$TMP_DIR/.tmp/hooked-sessions')
result = set_pr_number_for_issue(100, 456, session_dir)
assert result is True, f'Expected True, got {result}'

# Verify all fields preserved
with open(session_dir / 'sess456.json') as f:
    state = json.load(f)
    assert state.get('pr_number') == 456, f'Expected pr_number=456, got {state}'
    assert state.get('continuation_count') == 3, f'Expected continuation_count=3, got {state}'
    assert state.get('state') == 'in_progress', f'Expected state=in_progress, got {state}'

print('OK')
")

if [ "$output" != "OK" ]; then
  test_fail "set_pr_number_for_issue preserves fields: $output"
fi

test_pass "session pr_number helper works correctly"
