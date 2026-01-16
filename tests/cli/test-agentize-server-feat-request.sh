#!/usr/bin/env bash
# Test: server feat-request discovery, filtering, spawn, and cleanup
# Tests discover_candidate_feat_requests, filter_ready_feat_requests, spawn_feat_request, and _cleanup_feat_request

source "$(dirname "$0")/../common.sh"

test_info "server feat-request worker tests"

# Test 1: discover_candidate_feat_requests returns list of issue numbers
discover_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
from unittest.mock import patch, MagicMock

# Mock gh issue list to return sample output with agentize:dev-req label
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

# Test 3: filter_ready_feat_requests returns issues with agentize:dev-req but NOT agentize:plan
FEAT_REQUEST_ITEMS='[
  {"content": {"number": 42, "labels": {"nodes": [{"name": "agentize:dev-req"}]}}, "fieldValueByName": {"name": "Backlog"}},
  {"content": {"number": 43, "labels": {"nodes": [{"name": "agentize:dev-req"}, {"name": "agentize:plan"}]}}, "fieldValueByName": {"name": "Proposed"}},
  {"content": {"number": 44, "labels": {"nodes": [{"name": "agentize:dev-req"}]}}, "fieldValueByName": {"name": "Done"}},
  {"content": {"number": 45, "labels": {"nodes": [{"name": "agentize:dev-req"}]}}, "fieldValueByName": {"name": "In Progress"}}
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

# Test 4: filter_ready_feat_requests debug output contains [dev-req-filter] prefix
filter_debug_output=$(PYTHONPATH="$PROJECT_ROOT/python" HANDSOFF_DEBUG=1 python3 -c "
import json
from agentize.server.github import filter_ready_feat_requests

items = json.loads('''$FEAT_REQUEST_ITEMS''')
filter_ready_feat_requests(items)
" 2>&1)

if ! echo "$filter_debug_output" | grep -q '\[dev-req-filter\]'; then
  test_fail "Dev-req debug output missing [dev-req-filter] prefix"
fi

if ! echo "$filter_debug_output" | grep -q 'already has agentize:plan'; then
  test_fail "Feat-request debug output missing 'already has agentize:plan' reason"
fi

if ! echo "$filter_debug_output" | grep -q 'terminal status'; then
  test_fail "Feat-request debug output missing 'terminal status' reason"
fi

# Test 5: spawn_feat_request function exists, is callable, and has model parameter
spawn_import_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import inspect
from agentize.server.workers import spawn_feat_request

if not callable(spawn_feat_request):
    print('not-callable')
else:
    # Check signature includes model parameter
    sig = inspect.signature(spawn_feat_request)
    params = list(sig.parameters.keys())
    if 'model' not in params:
        print('missing-model-param')
    elif sig.parameters['model'].default is not None:
        print('model-default-not-none')
    else:
        print('True')
" 2>/dev/null)

if [ "$spawn_import_output" != "True" ]; then
  test_fail "spawn_feat_request should be importable, callable, and have model parameter with None default, got: $spawn_import_output"
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

# Test 7: _cleanup_feat_request removes agentize:dev-req label
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
    # Check that gh issue edit was called with --remove-label agentize:dev-req
    edit_called = any('--remove-label' in str(c) and 'agentize:dev-req' in str(c) for c in captured_calls)
    print('True' if edit_called else 'False')
" 2>/dev/null)

if [ "$cleanup_output" != "True" ]; then
  test_fail "_cleanup_feat_request should call gh issue edit --remove-label agentize:dev-req, got: $cleanup_output"
fi

# Test 8: _check_issue_has_label returns True for agentize:dev-req
label_check_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
from unittest.mock import patch, MagicMock

mock_result = MagicMock()
mock_result.returncode = 0
mock_result.stdout = 'agentize:dev-req\nbug\n'

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.workers import _check_issue_has_label
    result = _check_issue_has_label(42, 'agentize:dev-req')
    print('True' if result else 'False')
")

if [ "$label_check_output" != "True" ]; then
  test_fail "_check_issue_has_label should return True for agentize:dev-req, got: $label_check_output"
fi

test_pass "server feat-request worker tests work correctly"
