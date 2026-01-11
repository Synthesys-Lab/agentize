#!/usr/bin/env bash
# Test: server feat-request discovery, filtering, spawn, and cleanup
# Tests discover_candidate_feat_requests, filter_ready_feat_requests, spawn_feat_request, and _cleanup_feat_request

source "$(dirname "$0")/../common.sh"

test_info "server feat-request worker tests"

# Test 1: discover_candidate_feat_requests returns list of issue numbers
discover_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
from unittest.mock import patch, MagicMock

# Mock gh issue list to return sample output with agentize:feat-request label
mock_result = MagicMock()
mock_result.returncode = 0
mock_result.stdout = '42\tFeature request 1\n43\tFeature request 2\n'

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.github import discover_candidate_feat_requests
    issues = discover_candidate_feat_requests('owner', 'repo')
    print(' '.join(map(str, issues)))
")

if [ "$discover_output" != "42 43" ]; then
  test_fail "discover_candidate_feat_requests should return [42, 43], got [$discover_output]"
fi

# Test 2: discover_candidate_feat_requests returns empty list on gh failure
discover_fail_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
from unittest.mock import patch, MagicMock

# Mock gh issue list to fail
mock_result = MagicMock()
mock_result.returncode = 1
mock_result.stderr = 'error: not authenticated'

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.github import discover_candidate_feat_requests
    issues = discover_candidate_feat_requests('owner', 'repo')
    print(len(issues))
")

if [ "$discover_fail_output" != "0" ]; then
  test_fail "discover_candidate_feat_requests should return empty list on failure, got count: $discover_fail_output"
fi

# Test 3: filter_ready_feat_requests returns issues with agentize:feat-request but NOT agentize:plan
FEAT_REQUEST_ITEMS='[
  {"content": {"number": 42, "labels": {"nodes": [{"name": "agentize:feat-request"}]}}, "fieldValueByName": {"name": "Backlog"}},
  {"content": {"number": 43, "labels": {"nodes": [{"name": "agentize:feat-request"}, {"name": "agentize:plan"}]}}, "fieldValueByName": {"name": "Proposed"}},
  {"content": {"number": 44, "labels": {"nodes": [{"name": "agentize:feat-request"}]}}, "fieldValueByName": {"name": "Done"}},
  {"content": {"number": 45, "labels": {"nodes": [{"name": "agentize:feat-request"}]}}, "fieldValueByName": {"name": "In Progress"}}
]'

filter_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import json
from agentize.server.github import filter_ready_feat_requests

items = json.loads('''$FEAT_REQUEST_ITEMS''')
ready = filter_ready_feat_requests(items)
print(' '.join(map(str, ready)))
")

if [ "$filter_output" != "42" ]; then
  test_fail "Expected feat-request issues [42], got [$filter_output]"
fi

# Test 4: filter_ready_feat_requests debug output contains [feat-request-filter] prefix
filter_debug_output=$(PYTHONPATH="$PROJECT_ROOT/python" HANDSOFF_DEBUG=1 python3 -c "
import json
from agentize.server.github import filter_ready_feat_requests

items = json.loads('''$FEAT_REQUEST_ITEMS''')
filter_ready_feat_requests(items)
" 2>&1)

if ! echo "$filter_debug_output" | grep -q '\[feat-request-filter\]'; then
  test_fail "Feat-request debug output missing [feat-request-filter] prefix"
fi

if ! echo "$filter_debug_output" | grep -q 'already has agentize:plan'; then
  test_fail "Feat-request debug output missing 'already has agentize:plan' reason"
fi

if ! echo "$filter_debug_output" | grep -q 'terminal status'; then
  test_fail "Feat-request debug output missing 'terminal status' reason"
fi

# Test 5: spawn_feat_request function exists and is callable
spawn_import_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
from agentize.server.workers import spawn_feat_request
print('True' if callable(spawn_feat_request) else 'False')
" 2>/dev/null)

if [ "$spawn_import_output" != "True" ]; then
  test_fail "spawn_feat_request should be importable and callable, got: $spawn_import_output"
fi

# Test 6: spawn_feat_request returns (False, None) when wt spawn fails
spawn_fail_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import sys
import io
from unittest.mock import patch, MagicMock
import agentize.server.workers as workers_module

def mock_shell_run(cmd, **kwargs):
    if 'wt pathto' in cmd:
        return MagicMock(returncode=1, stdout='')  # Worktree doesn't exist
    if 'wt spawn' in cmd:
        return MagicMock(returncode=1, stdout='', stderr='error: spawn failed')
    return MagicMock(returncode=0, stdout='')

old_stdout = sys.stdout
with patch.object(workers_module, 'run_shell_function', side_effect=mock_shell_run):
    sys.stdout = io.StringIO()  # Suppress _log output
    success, pid = workers_module.spawn_feat_request(42)
    sys.stdout = old_stdout
    print(f'{success} {pid}')
" 2>/dev/null)

if [ "$spawn_fail_output" != "False None" ]; then
  test_fail "spawn_feat_request should return (False, None) on failure, got: $spawn_fail_output"
fi

# Test 7: _cleanup_feat_request removes agentize:feat-request label
cleanup_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
import sys
from unittest.mock import patch, MagicMock

captured_calls = []

def capture_run(*args, **kwargs):
    captured_calls.append(args[0] if args else kwargs.get('args', []))
    mock_result = MagicMock()
    mock_result.returncode = 0
    mock_result.stdout = ''
    return mock_result

import io
old_stdout = sys.stdout

with patch('subprocess.run', side_effect=capture_run):
    from agentize.server.workers import _cleanup_feat_request
    sys.stdout = io.StringIO()  # Suppress _log output
    _cleanup_feat_request(42)
    sys.stdout = old_stdout
    # Check that gh issue edit was called with --remove-label agentize:feat-request
    edit_called = any('--remove-label' in str(c) and 'agentize:feat-request' in str(c) for c in captured_calls)
    print('True' if edit_called else 'False')
" 2>/dev/null)

if [ "$cleanup_output" != "True" ]; then
  test_fail "_cleanup_feat_request should call gh issue edit --remove-label agentize:feat-request, got: $cleanup_output"
fi

# Test 8: _check_issue_has_label returns True for agentize:feat-request
label_check_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
from unittest.mock import patch, MagicMock

mock_result = MagicMock()
mock_result.returncode = 0
mock_result.stdout = 'agentize:feat-request\nbug\n'

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.workers import _check_issue_has_label
    result = _check_issue_has_label(42, 'agentize:feat-request')
    print('True' if result else 'False')
")

if [ "$label_check_output" != "True" ]; then
  test_fail "_check_issue_has_label should return True for agentize:feat-request, got: $label_check_output"
fi

test_pass "server feat-request worker tests work correctly"
