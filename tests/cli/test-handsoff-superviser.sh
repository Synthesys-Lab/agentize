#!/usr/bin/env bash
# Test: HANDSOFF_SUPERVISER environment variable and Claude guidance functionality

source "$(dirname "$0")/../common.sh"

test_info "HANDSOFF_SUPERVISER Claude guidance functionality"

# Test 1: Verify superviser disabled by default
test_info "Test 1: HANDSOFF_SUPERVISER disabled by default"
unset HANDSOFF_SUPERVISER
result=$(python3 << 'PYEOF'
import sys
import os
sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import _ask_claude_for_guidance

# With HANDSOFF_SUPERVISER not set or 0, should return None
guidance = _ask_claude_for_guidance('ultra-planner', 1, 10)
if guidance is None:
    print('PASS')
else:
    print(f'FAIL: Expected None when disabled, got {guidance}')
PYEOF
)
[ "$result" = "PASS" ] || test_fail "Superviser should be disabled by default"

# Test 2: Verify superviser disabled with explicit 0
test_info "Test 2: HANDSOFF_SUPERVISER=0 disables guidance"
result=$(HANDSOFF_SUPERVISER=0 python3 << 'PYEOF'
import sys
import os
sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import _ask_claude_for_guidance

guidance = _ask_claude_for_guidance('ultra-planner', 1, 10)
if guidance is None:
    print('PASS')
else:
    print(f'FAIL: Expected None with HANDSOFF_SUPERVISER=0')
PYEOF
)
[ "$result" = "PASS" ] || test_fail "Superviser should be disabled with HANDSOFF_SUPERVISER=0"

# Test 3: Verify superviser recognizes various enable values
test_info "Test 3: HANDSOFF_SUPERVISER accepts '1', 'true', 'on'"
for value in "1" "true" "on"; do
    result=$(HANDSOFF_SUPERVISER="$value" python3 << PYEOF
import sys
import os
import subprocess
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import _ask_claude_for_guidance

# Mock claude subprocess to avoid actual API calls
with patch('subprocess.check_output') as mock_subprocess:
    mock_subprocess.return_value = "Test guidance response"

    guidance = _ask_claude_for_guidance('ultra-planner', 1, 10)

    # If superviser is enabled, subprocess should be called
    if mock_subprocess.called:
        print('PASS')
    else:
        print(f'FAIL: subprocess not called for HANDSOFF_SUPERVISER=$value')
PYEOF
)
    [ "$result" = "PASS" ] || test_fail "Superviser should be enabled with HANDSOFF_SUPERVISER=$value"
done

# Test 4: Verify superviser disabled with false/off values
test_info "Test 4: HANDSOFF_SUPERVISER rejects 'false', 'off'"
for value in "false" "off"; do
    result=$(HANDSOFF_SUPERVISER="$value" python3 << PYEOF
import sys
import os
sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import _ask_claude_for_guidance

guidance = _ask_claude_for_guidance('ultra-planner', 1, 10)
if guidance is None:
    print('PASS')
else:
    print(f'FAIL: Expected None with HANDSOFF_SUPERVISER=$value')
PYEOF
)
    [ "$result" = "PASS" ] || test_fail "Superviser should be disabled with HANDSOFF_SUPERVISER=$value"
done

# Test 5: Verify get_continuation_prompt falls back to static template when superviser disabled
test_info "Test 5: get_continuation_prompt returns static template when superviser disabled"
result=$(python3 << 'PYEOF'
import sys
import os
sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import get_continuation_prompt, ULTRA_PLANNER

# With superviser disabled, should get static template containing workflow guidance
prompt = get_continuation_prompt(
    ULTRA_PLANNER,
    'test-session-id',
    'test-file.json',
    1,
    10
)

# Check that static template is returned
if 'comprehensive plan' in prompt and 'GitHub Issue' in prompt:
    print('PASS')
else:
    print(f'FAIL: Expected static template content in prompt')
PYEOF
)
[ "$result" = "PASS" ] || test_fail "get_continuation_prompt should use static template when disabled"

# Test 6: Verify workflow goals are defined correctly
test_info "Test 6: Workflow goals are defined for all workflows"
result=$(python3 << 'PYEOF'
import sys
import os
sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import _get_workflow_goal, ULTRA_PLANNER, ISSUE_TO_IMPL, PLAN_TO_ISSUE, SETUP_VIEWBOARD, SYNC_MASTER

workflows = [ULTRA_PLANNER, ISSUE_TO_IMPL, PLAN_TO_ISSUE, SETUP_VIEWBOARD, SYNC_MASTER]
all_good = True

for workflow in workflows:
    goal = _get_workflow_goal(workflow)
    if not goal or goal == 'Complete the current workflow':
        print(f'FAIL: No custom goal for {workflow}')
        all_good = False

if all_good:
    print('PASS')
PYEOF
)
[ "$result" = "PASS" ] || test_fail "Workflow goals should be defined"

# Test 7: Verify continuation count is passed correctly to Claude
test_info "Test 7: Continuation context is passed to Claude prompt"
result=$(HANDSOFF_SUPERVISER=1 python3 << 'PYEOF'
import sys
import os
import subprocess
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import _ask_claude_for_guidance

# Mock claude subprocess to capture the prompt
with patch('subprocess.check_output') as mock_subprocess:
    mock_subprocess.return_value = "Test response"

    guidance = _ask_claude_for_guidance('issue-to-impl', 3, 10)

    # Check that the subprocess was called with correct prompt content
    if mock_subprocess.called:
        call_args = mock_subprocess.call_args
        prompt = call_args[1]['input']  # Get the input parameter

        if 'issue-to-impl' in prompt and '3 / 10' in prompt and 'Implement an issue' in prompt:
            print('PASS')
        else:
            print(f'FAIL: Prompt missing context: {prompt[:100]}')
    else:
        print('FAIL: subprocess not called')
PYEOF
)
[ "$result" = "PASS" ] || test_fail "Continuation context should be in Claude prompt"

# Test 8: Verify timeout handling (fallback to None)
test_info "Test 8: Claude timeout falls back gracefully"
result=$(HANDSOFF_SUPERVISER=1 python3 << 'PYEOF'
import sys
import os
import subprocess
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import _ask_claude_for_guidance

# Mock subprocess to raise TimeoutExpired
with patch('subprocess.check_output') as mock_subprocess:
    mock_subprocess.side_effect = subprocess.TimeoutExpired('claude', 60)

    guidance = _ask_claude_for_guidance('ultra-planner', 1, 10)

    # Should return None on timeout (fallback)
    if guidance is None:
        print('PASS')
    else:
        print(f'FAIL: Expected None on timeout, got {guidance}')
PYEOF
)
[ "$result" = "PASS" ] || test_fail "Should handle Claude timeout gracefully"

# Test 9: Verify CalledProcessError handling
test_info "Test 9: Claude subprocess error falls back gracefully"
result=$(HANDSOFF_SUPERVISER=1 python3 << 'PYEOF'
import sys
import os
import subprocess
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import _ask_claude_for_guidance

# Mock subprocess to raise CalledProcessError
with patch('subprocess.check_output') as mock_subprocess:
    mock_subprocess.side_effect = subprocess.CalledProcessError(1, 'claude', output='error')

    guidance = _ask_claude_for_guidance('plan-to-issue', 2, 5)

    # Should return None on error (fallback)
    if guidance is None:
        print('PASS')
    else:
        print(f'FAIL: Expected None on subprocess error, got {guidance}')
PYEOF
)
[ "$result" = "PASS" ] || test_fail "Should handle subprocess errors gracefully"

# Test 10: Verify backward compatibility (static template format preserved)
test_info "Test 10: Static template format preserved with all variables"
result=$(python3 << 'PYEOF'
import sys
import os
sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import get_continuation_prompt, SYNC_MASTER

# Get static template for sync-master workflow (which uses pr_no)
prompt = get_continuation_prompt(
    SYNC_MASTER,
    'session-12345',
    '/tmp/test.json',
    2,
    10,
    pr_no='42'
)

# Verify all template variables were substituted
if ('{' not in prompt and '}' not in prompt and
    'session-12345' in prompt and
    '/tmp/test.json' in prompt and
    '2/10' in prompt and
    '42' in prompt):
    print('PASS')
else:
    print(f'FAIL: Template variables not properly substituted')
PYEOF
)
[ "$result" = "PASS" ] || test_fail "Static template should preserve format and substitute variables"

# Test 11: Verify environment variable case insensitivity
test_info "Test 11: HANDSOFF_SUPERVISER is case insensitive"
for value in "TRUE" "True" "ON" "On"; do
    result=$(HANDSOFF_SUPERVISER="$value" python3 << PYEOF
import sys
import os
import subprocess
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.environ.get('PROJECT_ROOT', '.'), '.claude-plugin'))

from lib.workflow import _ask_claude_for_guidance

# Mock claude subprocess
with patch('subprocess.check_output') as mock_subprocess:
    mock_subprocess.return_value = "Test response"

    guidance = _ask_claude_for_guidance('sync-master', 1, 1)

    # Should be enabled regardless of case
    if mock_subprocess.called:
        print('PASS')
    else:
        print(f'FAIL: Not enabled for HANDSOFF_SUPERVISER=$value')
PYEOF
)
    [ "$result" = "PASS" ] || test_fail "HANDSOFF_SUPERVISER should accept various case combinations"
done

test_pass "HANDSOFF_SUPERVISER Claude guidance functionality works correctly"
