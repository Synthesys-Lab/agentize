#!/usr/bin/env bash
# Test: server refinement spawn and cleanup functions
# Tests spawn_refinement, _check_issue_has_label, and _cleanup_refinement

source "$(dirname "$0")/../common.sh"

test_info "server refinement spawn and cleanup"

# Test 1: _check_issue_has_label returns True when label present
label_check_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
from unittest.mock import patch, MagicMock

# Mock gh issue view to return labels including agentize:refine
mock_result = MagicMock()
mock_result.returncode = 0
mock_result.stdout = 'agentize:plan\nagentize:refine\nbug\n'

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.workers import _check_issue_has_label
    result = _check_issue_has_label(42, 'agentize:refine')
    print('True' if result else 'False')
")

if [ "$label_check_output" != "True" ]; then
  test_fail "_check_issue_has_label should return True when label present, got: $label_check_output"
fi

# Test 2: _check_issue_has_label returns False when label absent
label_check_absent=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
from unittest.mock import patch, MagicMock

# Mock gh issue view to return labels without agentize:refine
mock_result = MagicMock()
mock_result.returncode = 0
mock_result.stdout = 'agentize:plan\nbug\n'

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.workers import _check_issue_has_label
    result = _check_issue_has_label(42, 'agentize:refine')
    print('True' if result else 'False')
")

if [ "$label_check_absent" != "False" ]; then
  test_fail "_check_issue_has_label should return False when label absent, got: $label_check_absent"
fi

# Test 3: _check_issue_has_label returns False on gh failure
label_check_fail=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
from unittest.mock import patch, MagicMock

# Mock gh issue view to fail
mock_result = MagicMock()
mock_result.returncode = 1
mock_result.stdout = ''

with patch('subprocess.run', return_value=mock_result):
    from agentize.server.workers import _check_issue_has_label
    result = _check_issue_has_label(42, 'agentize:refine')
    print('True' if result else 'False')
")

if [ "$label_check_fail" != "False" ]; then
  test_fail "_check_issue_has_label should return False on gh failure, got: $label_check_fail"
fi

# Test 4: _cleanup_refinement calls gh issue edit to remove label
cleanup_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import subprocess
import sys
from unittest.mock import patch, MagicMock, call

captured_calls = []

def capture_run(*args, **kwargs):
    captured_calls.append(args[0] if args else kwargs.get('args', []))
    mock_result = MagicMock()
    mock_result.returncode = 0
    mock_result.stdout = ''
    return mock_result

# Suppress _log output by redirecting stdout temporarily
import io
old_stdout = sys.stdout

with patch('subprocess.run', side_effect=capture_run):
    from agentize.server.workers import _cleanup_refinement
    sys.stdout = io.StringIO()  # Suppress _log output
    _cleanup_refinement(42)
    sys.stdout = old_stdout
    # Check that gh issue edit was called with --remove-label
    edit_called = any('--remove-label' in str(c) and 'agentize:refine' in str(c) for c in captured_calls)
    print('True' if edit_called else 'False')
" 2>/dev/null)

if [ "$cleanup_output" != "True" ]; then
  test_fail "_cleanup_refinement should call gh issue edit --remove-label agentize:refine, got: $cleanup_output"
fi

# Test 5: spawn_refinement function exists and is importable with model parameter
spawn_import_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import inspect
from agentize.server.workers import spawn_refinement

# Verify it's a callable function
if not callable(spawn_refinement):
    print('not-callable')
else:
    # Check signature includes model parameter
    sig = inspect.signature(spawn_refinement)
    params = list(sig.parameters.keys())
    if 'model' not in params:
        print('missing-model-param')
    elif sig.parameters['model'].default is not None:
        print('model-default-not-none')
    else:
        print('True')
" 2>/dev/null)

if [ "$spawn_import_output" != "True" ]; then
  test_fail "spawn_refinement should be importable, callable, and have model parameter with None default, got: $spawn_import_output"
fi

# Test 6: spawn_refinement returns (False, None) when wt spawn fails
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
    success, pid = workers_module.spawn_refinement(42)
    sys.stdout = old_stdout
    print(f'{success} {pid}')
" 2>/dev/null)

if [ "$spawn_fail_output" != "False None" ]; then
  test_fail "spawn_refinement should return (False, None) on failure, got: $spawn_fail_output"
fi

# Test 7: spawn_refinement reuses existing worktree (skips wt spawn when exists)
spawn_reuse_output=$(PYTHONPATH="$PROJECT_ROOT/python" python3 -c "
import sys
import io
from unittest.mock import patch, MagicMock
from pathlib import Path
import agentize.server.workers as workers_module

spawn_called = []

def mock_shell_run(cmd, **kwargs):
    if 'wt spawn' in cmd:
        spawn_called.append(cmd)
        return MagicMock(returncode=0, stdout='')
    if 'wt pathto' in cmd:
        return MagicMock(returncode=0, stdout='/tmp/test-worktree')  # Worktree exists
    if 'wt_claim_issue_status' in cmd:
        return MagicMock(returncode=0, stdout='')
    return MagicMock(returncode=0, stdout='')

mock_popen = MagicMock()
mock_popen.pid = 12345

old_stdout = sys.stdout
with patch.object(workers_module, 'run_shell_function', side_effect=mock_shell_run):
    with patch.object(workers_module.subprocess, 'Popen', return_value=mock_popen):
        with patch.object(Path, 'mkdir'):
            with patch('builtins.open', MagicMock()):
                sys.stdout = io.StringIO()  # Suppress _log output
                success, pid = workers_module.spawn_refinement(42)
                sys.stdout = old_stdout
                # wt spawn should NOT be called because worktree already exists
                print(f'{len(spawn_called)}')
" 2>/dev/null)

if [ "$spawn_reuse_output" != "0" ]; then
  test_fail "spawn_refinement should not call wt spawn when worktree exists, got spawn call count: $spawn_reuse_output"
fi

test_pass "server refinement spawn and cleanup work correctly"
