#!/usr/bin/env bash
# Test: Unified workflow module functionality

source "$(dirname "$0")/../common.sh"

test_info "Workflow module tests"

# Helper to run Python code that imports the workflow module
run_workflow_python() {
    local python_code="$1"
    PYTHONPATH="$PROJECT_ROOT/python" python3 -c "$python_code"
}

# ============================================================
# Test detect_workflow()
# ============================================================

test_info "Test 1: detect_workflow('/ultra-planner') → ultra-planner"
RESULT=$(run_workflow_python "from agentize.workflow import detect_workflow; print(detect_workflow('/ultra-planner'))")
[ "$RESULT" = "ultra-planner" ] || test_fail "Expected 'ultra-planner', got '$RESULT'"

test_info "Test 2: detect_workflow('/ultra-planner --refine 42') → ultra-planner"
RESULT=$(run_workflow_python "from agentize.workflow import detect_workflow; print(detect_workflow('/ultra-planner --refine 42'))")
[ "$RESULT" = "ultra-planner" ] || test_fail "Expected 'ultra-planner', got '$RESULT'"

test_info "Test 3: detect_workflow('/issue-to-impl 42') → issue-to-impl"
RESULT=$(run_workflow_python "from agentize.workflow import detect_workflow; print(detect_workflow('/issue-to-impl 42'))")
[ "$RESULT" = "issue-to-impl" ] || test_fail "Expected 'issue-to-impl', got '$RESULT'"

test_info "Test 4: detect_workflow('/plan-to-issue') → plan-to-issue"
RESULT=$(run_workflow_python "from agentize.workflow import detect_workflow; print(detect_workflow('/plan-to-issue'))")
[ "$RESULT" = "plan-to-issue" ] || test_fail "Expected 'plan-to-issue', got '$RESULT'"

test_info "Test 5: detect_workflow('/setup-viewboard') → setup-viewboard"
RESULT=$(run_workflow_python "from agentize.workflow import detect_workflow; print(detect_workflow('/setup-viewboard'))")
[ "$RESULT" = "setup-viewboard" ] || test_fail "Expected 'setup-viewboard', got '$RESULT'"

test_info "Test 6: detect_workflow('/sync-master 123') → sync-master"
RESULT=$(run_workflow_python "from agentize.workflow import detect_workflow; print(detect_workflow('/sync-master 123'))")
[ "$RESULT" = "sync-master" ] || test_fail "Expected 'sync-master', got '$RESULT'"

test_info "Test 7: detect_workflow('Hello, how are you?') → None"
RESULT=$(run_workflow_python "from agentize.workflow import detect_workflow; print(detect_workflow('Hello, how are you?'))")
[ "$RESULT" = "None" ] || test_fail "Expected 'None', got '$RESULT'"

test_info "Test 8: detect_workflow('/unknown-command') → None"
RESULT=$(run_workflow_python "from agentize.workflow import detect_workflow; print(detect_workflow('/unknown-command'))")
[ "$RESULT" = "None" ] || test_fail "Expected 'None', got '$RESULT'"

# ============================================================
# Test extract_issue_no()
# ============================================================

test_info "Test 9: extract_issue_no('/issue-to-impl 42') → 42"
RESULT=$(run_workflow_python "from agentize.workflow import extract_issue_no; print(extract_issue_no('/issue-to-impl 42'))")
[ "$RESULT" = "42" ] || test_fail "Expected '42', got '$RESULT'"

test_info "Test 10: extract_issue_no('/ultra-planner --refine 123') → 123"
RESULT=$(run_workflow_python "from agentize.workflow import extract_issue_no; print(extract_issue_no('/ultra-planner --refine 123'))")
[ "$RESULT" = "123" ] || test_fail "Expected '123', got '$RESULT'"

test_info "Test 11: extract_issue_no('/ultra-planner --from-issue 456') → 456"
RESULT=$(run_workflow_python "from agentize.workflow import extract_issue_no; print(extract_issue_no('/ultra-planner --from-issue 456'))")
[ "$RESULT" = "456" ] || test_fail "Expected '456', got '$RESULT'"

test_info "Test 12: extract_issue_no('/ultra-planner new feature') → None"
RESULT=$(run_workflow_python "from agentize.workflow import extract_issue_no; print(extract_issue_no('/ultra-planner new feature'))")
[ "$RESULT" = "None" ] || test_fail "Expected 'None', got '$RESULT'"

test_info "Test 13: extract_issue_no('/plan-to-issue') → None"
RESULT=$(run_workflow_python "from agentize.workflow import extract_issue_no; print(extract_issue_no('/plan-to-issue'))")
[ "$RESULT" = "None" ] || test_fail "Expected 'None', got '$RESULT'"

# ============================================================
# Test extract_pr_no()
# ============================================================

test_info "Test 14: extract_pr_no('/sync-master 789') → 789"
RESULT=$(run_workflow_python "from agentize.workflow import extract_pr_no; print(extract_pr_no('/sync-master 789'))")
[ "$RESULT" = "789" ] || test_fail "Expected '789', got '$RESULT'"

test_info "Test 15: extract_pr_no('/sync-master') → None"
RESULT=$(run_workflow_python "from agentize.workflow import extract_pr_no; print(extract_pr_no('/sync-master'))")
[ "$RESULT" = "None" ] || test_fail "Expected 'None', got '$RESULT'"

# ============================================================
# Test has_continuation_prompt()
# ============================================================

test_info "Test 16: has_continuation_prompt('ultra-planner') → True"
RESULT=$(run_workflow_python "from agentize.workflow import has_continuation_prompt; print(has_continuation_prompt('ultra-planner'))")
[ "$RESULT" = "True" ] || test_fail "Expected 'True', got '$RESULT'"

test_info "Test 17: has_continuation_prompt('issue-to-impl') → True"
RESULT=$(run_workflow_python "from agentize.workflow import has_continuation_prompt; print(has_continuation_prompt('issue-to-impl'))")
[ "$RESULT" = "True" ] || test_fail "Expected 'True', got '$RESULT'"

test_info "Test 18: has_continuation_prompt('plan-to-issue') → True"
RESULT=$(run_workflow_python "from agentize.workflow import has_continuation_prompt; print(has_continuation_prompt('plan-to-issue'))")
[ "$RESULT" = "True" ] || test_fail "Expected 'True', got '$RESULT'"

test_info "Test 19: has_continuation_prompt('setup-viewboard') → True"
RESULT=$(run_workflow_python "from agentize.workflow import has_continuation_prompt; print(has_continuation_prompt('setup-viewboard'))")
[ "$RESULT" = "True" ] || test_fail "Expected 'True', got '$RESULT'"

test_info "Test 20: has_continuation_prompt('sync-master') → True"
RESULT=$(run_workflow_python "from agentize.workflow import has_continuation_prompt; print(has_continuation_prompt('sync-master'))")
[ "$RESULT" = "True" ] || test_fail "Expected 'True', got '$RESULT'"

test_info "Test 21: has_continuation_prompt('unknown-workflow') → False"
RESULT=$(run_workflow_python "from agentize.workflow import has_continuation_prompt; print(has_continuation_prompt('unknown-workflow'))")
[ "$RESULT" = "False" ] || test_fail "Expected 'False', got '$RESULT'"

# ============================================================
# Test get_continuation_prompt()
# ============================================================

test_info "Test 22: get_continuation_prompt() returns formatted string with session_id"
RESULT=$(run_workflow_python "
from agentize.workflow import get_continuation_prompt
prompt = get_continuation_prompt('ultra-planner', 'test-session-123', '/tmp/test.json', 3, 10)
print('SESSION_ID_OK' if 'test-session-123' in prompt else 'SESSION_ID_MISSING')
")
[ "$RESULT" = "SESSION_ID_OK" ] || test_fail "Expected session_id in prompt, got '$RESULT'"

test_info "Test 23: get_continuation_prompt() returns formatted string with count"
RESULT=$(run_workflow_python "
from agentize.workflow import get_continuation_prompt
prompt = get_continuation_prompt('ultra-planner', 'test-session-123', '/tmp/test.json', 3, 10)
print('COUNT_OK' if '3/10' in prompt else 'COUNT_MISSING')
")
[ "$RESULT" = "COUNT_OK" ] || test_fail "Expected count (3/10) in prompt, got '$RESULT'"

test_info "Test 24: get_continuation_prompt() returns formatted string with fname"
RESULT=$(run_workflow_python "
from agentize.workflow import get_continuation_prompt
prompt = get_continuation_prompt('ultra-planner', 'test-session-123', '/tmp/test.json', 3, 10)
print('FNAME_OK' if '/tmp/test.json' in prompt else 'FNAME_MISSING')
")
[ "$RESULT" = "FNAME_OK" ] || test_fail "Expected fname in prompt, got '$RESULT'"

test_info "Test 25: get_continuation_prompt() for issue-to-impl includes milestone text"
RESULT=$(run_workflow_python "
from agentize.workflow import get_continuation_prompt
prompt = get_continuation_prompt('issue-to-impl', 'test-session', '/tmp/test.json', 1, 10)
print('MILESTONE_OK' if 'milestone' in prompt.lower() else 'MILESTONE_MISSING')
")
[ "$RESULT" = "MILESTONE_OK" ] || test_fail "Expected 'milestone' in issue-to-impl prompt, got '$RESULT'"

test_info "Test 26: get_continuation_prompt() for setup-viewboard includes correct text"
RESULT=$(run_workflow_python "
from agentize.workflow import get_continuation_prompt
prompt = get_continuation_prompt('setup-viewboard', 'test-session', '/tmp/test.json', 1, 10)
print('VIEWBOARD_OK' if 'Projects v2 board' in prompt else 'VIEWBOARD_MISSING')
")
[ "$RESULT" = "VIEWBOARD_OK" ] || test_fail "Expected 'Projects v2 board' in setup-viewboard prompt, got '$RESULT'"

test_info "Test 27: get_continuation_prompt() for unknown workflow returns empty string"
RESULT=$(run_workflow_python "
from agentize.workflow import get_continuation_prompt
prompt = get_continuation_prompt('unknown-workflow', 'test-session', '/tmp/test.json', 1, 10)
print('EMPTY' if prompt == '' else 'NOT_EMPTY')
")
[ "$RESULT" = "EMPTY" ] || test_fail "Expected empty string for unknown workflow, got '$RESULT'"

# ============================================================
# Test workflow constants
# ============================================================

test_info "Test 28: ULTRA_PLANNER constant equals 'ultra-planner'"
RESULT=$(run_workflow_python "from agentize.workflow import ULTRA_PLANNER; print(ULTRA_PLANNER)")
[ "$RESULT" = "ultra-planner" ] || test_fail "Expected 'ultra-planner', got '$RESULT'"

test_info "Test 29: ISSUE_TO_IMPL constant equals 'issue-to-impl'"
RESULT=$(run_workflow_python "from agentize.workflow import ISSUE_TO_IMPL; print(ISSUE_TO_IMPL)")
[ "$RESULT" = "issue-to-impl" ] || test_fail "Expected 'issue-to-impl', got '$RESULT'"

test_info "Test 30: PLAN_TO_ISSUE constant equals 'plan-to-issue'"
RESULT=$(run_workflow_python "from agentize.workflow import PLAN_TO_ISSUE; print(PLAN_TO_ISSUE)")
[ "$RESULT" = "plan-to-issue" ] || test_fail "Expected 'plan-to-issue', got '$RESULT'"

test_info "Test 31: SETUP_VIEWBOARD constant equals 'setup-viewboard'"
RESULT=$(run_workflow_python "from agentize.workflow import SETUP_VIEWBOARD; print(SETUP_VIEWBOARD)")
[ "$RESULT" = "setup-viewboard" ] || test_fail "Expected 'setup-viewboard', got '$RESULT'"

test_info "Test 32: SYNC_MASTER constant equals 'sync-master'"
RESULT=$(run_workflow_python "from agentize.workflow import SYNC_MASTER; print(SYNC_MASTER)")
[ "$RESULT" = "sync-master" ] || test_fail "Expected 'sync-master', got '$RESULT'"

test_pass "Workflow module works correctly"
