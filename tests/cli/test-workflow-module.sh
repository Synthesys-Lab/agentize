#!/usr/bin/env bash
# Test: Unified workflow module functionality

source "$(dirname "$0")/../common.sh"

test_info "Workflow module tests"

# Helper to run Python code that imports the workflow module
# Disable HANDSOFF_SUPERVISOR to test static template behavior
run_workflow_python() {
    local python_code="$1"
    HANDSOFF_SUPERVISOR=none PYTHONPATH="$PROJECT_ROOT/.claude-plugin" python3 -c "$python_code"
}

# Helper to run Python code with custom env vars
# Uses eval to ensure proper word splitting in both bash and zsh
run_workflow_python_env() {
    local env_vars="$1"
    local python_code="$2"
    eval "$env_vars PYTHONPATH=\"\$PROJECT_ROOT/.claude-plugin\" python3 -c \"\$python_code\""
}

# ============================================================
# Test detect_workflow()
# ============================================================

test_info "Test 1: detect_workflow('/ultra-planner') → ultra-planner"
RESULT=$(run_workflow_python "from lib.workflow import detect_workflow; print(detect_workflow('/ultra-planner'))")
[ "$RESULT" = "ultra-planner" ] || test_fail "Expected 'ultra-planner', got '$RESULT'"

test_info "Test 2: detect_workflow('/ultra-planner --refine 42') → ultra-planner"
RESULT=$(run_workflow_python "from lib.workflow import detect_workflow; print(detect_workflow('/ultra-planner --refine 42'))")
[ "$RESULT" = "ultra-planner" ] || test_fail "Expected 'ultra-planner', got '$RESULT'"

test_info "Test 3: detect_workflow('/issue-to-impl 42') → issue-to-impl"
RESULT=$(run_workflow_python "from lib.workflow import detect_workflow; print(detect_workflow('/issue-to-impl 42'))")
[ "$RESULT" = "issue-to-impl" ] || test_fail "Expected 'issue-to-impl', got '$RESULT'"

test_info "Test 4: detect_workflow('/plan-to-issue') → plan-to-issue"
RESULT=$(run_workflow_python "from lib.workflow import detect_workflow; print(detect_workflow('/plan-to-issue'))")
[ "$RESULT" = "plan-to-issue" ] || test_fail "Expected 'plan-to-issue', got '$RESULT'"

test_info "Test 5: detect_workflow('/setup-viewboard') → setup-viewboard"
RESULT=$(run_workflow_python "from lib.workflow import detect_workflow; print(detect_workflow('/setup-viewboard'))")
[ "$RESULT" = "setup-viewboard" ] || test_fail "Expected 'setup-viewboard', got '$RESULT'"

test_info "Test 6: detect_workflow('/sync-master 123') → sync-master"
RESULT=$(run_workflow_python "from lib.workflow import detect_workflow; print(detect_workflow('/sync-master 123'))")
[ "$RESULT" = "sync-master" ] || test_fail "Expected 'sync-master', got '$RESULT'"

test_info "Test 7: detect_workflow('Hello, how are you?') → None"
RESULT=$(run_workflow_python "from lib.workflow import detect_workflow; print(detect_workflow('Hello, how are you?'))")
[ "$RESULT" = "None" ] || test_fail "Expected 'None', got '$RESULT'"

test_info "Test 8: detect_workflow('/unknown-command') → None"
RESULT=$(run_workflow_python "from lib.workflow import detect_workflow; print(detect_workflow('/unknown-command'))")
[ "$RESULT" = "None" ] || test_fail "Expected 'None', got '$RESULT'"

# ============================================================
# Test extract_issue_no()
# ============================================================

test_info "Test 9: extract_issue_no('/issue-to-impl 42') → 42"
RESULT=$(run_workflow_python "from lib.workflow import extract_issue_no; print(extract_issue_no('/issue-to-impl 42'))")
[ "$RESULT" = "42" ] || test_fail "Expected '42', got '$RESULT'"

test_info "Test 10: extract_issue_no('/ultra-planner --refine 123') → 123"
RESULT=$(run_workflow_python "from lib.workflow import extract_issue_no; print(extract_issue_no('/ultra-planner --refine 123'))")
[ "$RESULT" = "123" ] || test_fail "Expected '123', got '$RESULT'"

test_info "Test 11: extract_issue_no('/ultra-planner --from-issue 456') → 456"
RESULT=$(run_workflow_python "from lib.workflow import extract_issue_no; print(extract_issue_no('/ultra-planner --from-issue 456'))")
[ "$RESULT" = "456" ] || test_fail "Expected '456', got '$RESULT'"

test_info "Test 12: extract_issue_no('/ultra-planner new feature') → None"
RESULT=$(run_workflow_python "from lib.workflow import extract_issue_no; print(extract_issue_no('/ultra-planner new feature'))")
[ "$RESULT" = "None" ] || test_fail "Expected 'None', got '$RESULT'"

test_info "Test 13: extract_issue_no('/plan-to-issue') → None"
RESULT=$(run_workflow_python "from lib.workflow import extract_issue_no; print(extract_issue_no('/plan-to-issue'))")
[ "$RESULT" = "None" ] || test_fail "Expected 'None', got '$RESULT'"

# ============================================================
# Test extract_pr_no()
# ============================================================

test_info "Test 14: extract_pr_no('/sync-master 789') → 789"
RESULT=$(run_workflow_python "from lib.workflow import extract_pr_no; print(extract_pr_no('/sync-master 789'))")
[ "$RESULT" = "789" ] || test_fail "Expected '789', got '$RESULT'"

test_info "Test 15: extract_pr_no('/sync-master') → None"
RESULT=$(run_workflow_python "from lib.workflow import extract_pr_no; print(extract_pr_no('/sync-master'))")
[ "$RESULT" = "None" ] || test_fail "Expected 'None', got '$RESULT'"

# ============================================================
# Test has_continuation_prompt()
# ============================================================

test_info "Test 16: has_continuation_prompt('ultra-planner') → True"
RESULT=$(run_workflow_python "from lib.workflow import has_continuation_prompt; print(has_continuation_prompt('ultra-planner'))")
[ "$RESULT" = "True" ] || test_fail "Expected 'True', got '$RESULT'"

test_info "Test 17: has_continuation_prompt('issue-to-impl') → True"
RESULT=$(run_workflow_python "from lib.workflow import has_continuation_prompt; print(has_continuation_prompt('issue-to-impl'))")
[ "$RESULT" = "True" ] || test_fail "Expected 'True', got '$RESULT'"

test_info "Test 18: has_continuation_prompt('plan-to-issue') → True"
RESULT=$(run_workflow_python "from lib.workflow import has_continuation_prompt; print(has_continuation_prompt('plan-to-issue'))")
[ "$RESULT" = "True" ] || test_fail "Expected 'True', got '$RESULT'"

test_info "Test 19: has_continuation_prompt('setup-viewboard') → True"
RESULT=$(run_workflow_python "from lib.workflow import has_continuation_prompt; print(has_continuation_prompt('setup-viewboard'))")
[ "$RESULT" = "True" ] || test_fail "Expected 'True', got '$RESULT'"

test_info "Test 20: has_continuation_prompt('sync-master') → True"
RESULT=$(run_workflow_python "from lib.workflow import has_continuation_prompt; print(has_continuation_prompt('sync-master'))")
[ "$RESULT" = "True" ] || test_fail "Expected 'True', got '$RESULT'"

test_info "Test 21: has_continuation_prompt('unknown-workflow') → False"
RESULT=$(run_workflow_python "from lib.workflow import has_continuation_prompt; print(has_continuation_prompt('unknown-workflow'))")
[ "$RESULT" = "False" ] || test_fail "Expected 'False', got '$RESULT'"

# ============================================================
# Test get_continuation_prompt()
# ============================================================

test_info "Test 22: get_continuation_prompt() returns formatted string with session_id"
RESULT=$(run_workflow_python "
from lib.workflow import get_continuation_prompt
prompt = get_continuation_prompt('ultra-planner', 'test-session-123', '/tmp/test.json', 3, 10)
print('SESSION_ID_OK' if 'test-session-123' in prompt else 'SESSION_ID_MISSING')
")
[ "$RESULT" = "SESSION_ID_OK" ] || test_fail "Expected session_id in prompt, got '$RESULT'"

test_info "Test 23: get_continuation_prompt() returns formatted string with count"
RESULT=$(run_workflow_python "
from lib.workflow import get_continuation_prompt
prompt = get_continuation_prompt('ultra-planner', 'test-session-123', '/tmp/test.json', 3, 10)
print('COUNT_OK' if '3/10' in prompt else 'COUNT_MISSING')
")
[ "$RESULT" = "COUNT_OK" ] || test_fail "Expected count (3/10) in prompt, got '$RESULT'"

test_info "Test 24: get_continuation_prompt() returns formatted string with fname"
RESULT=$(run_workflow_python "
from lib.workflow import get_continuation_prompt
prompt = get_continuation_prompt('ultra-planner', 'test-session-123', '/tmp/test.json', 3, 10)
print('FNAME_OK' if '/tmp/test.json' in prompt else 'FNAME_MISSING')
")
[ "$RESULT" = "FNAME_OK" ] || test_fail "Expected fname in prompt, got '$RESULT'"

test_info "Test 25: get_continuation_prompt() for issue-to-impl includes milestone text"
RESULT=$(run_workflow_python "
from lib.workflow import get_continuation_prompt
prompt = get_continuation_prompt('issue-to-impl', 'test-session', '/tmp/test.json', 1, 10)
print('MILESTONE_OK' if 'milestone' in prompt.lower() else 'MILESTONE_MISSING')
")
[ "$RESULT" = "MILESTONE_OK" ] || test_fail "Expected 'milestone' in issue-to-impl prompt, got '$RESULT'"

test_info "Test 26: get_continuation_prompt() for setup-viewboard includes correct text"
RESULT=$(run_workflow_python "
from lib.workflow import get_continuation_prompt
prompt = get_continuation_prompt('setup-viewboard', 'test-session', '/tmp/test.json', 1, 10)
print('VIEWBOARD_OK' if 'Projects v2 board' in prompt else 'VIEWBOARD_MISSING')
")
[ "$RESULT" = "VIEWBOARD_OK" ] || test_fail "Expected 'Projects v2 board' in setup-viewboard prompt, got '$RESULT'"

test_info "Test 27: get_continuation_prompt() for unknown workflow returns empty string"
RESULT=$(run_workflow_python "
from lib.workflow import get_continuation_prompt
prompt = get_continuation_prompt('unknown-workflow', 'test-session', '/tmp/test.json', 1, 10)
print('EMPTY' if prompt == '' else 'NOT_EMPTY')
")
[ "$RESULT" = "EMPTY" ] || test_fail "Expected empty string for unknown workflow, got '$RESULT'"

# ============================================================
# Test plan context in continuation prompt
# ============================================================

test_info "Test 27a: get_continuation_prompt() for issue-to-impl includes plan_path when provided"
RESULT=$(run_workflow_python "
from lib.workflow import get_continuation_prompt
prompt = get_continuation_prompt('issue-to-impl', 'test-session', '/tmp/test.json', 1, 10, plan_path='/tmp/plan-of-issue-42.md')
print('PLAN_PATH_OK' if '/tmp/plan-of-issue-42.md' in prompt else 'PLAN_PATH_MISSING')
")
[ "$RESULT" = "PLAN_PATH_OK" ] || test_fail "Expected plan_path in issue-to-impl prompt, got '$RESULT'"

test_info "Test 27b: get_continuation_prompt() for issue-to-impl includes plan_excerpt when provided"
RESULT=$(run_workflow_python "
from lib.workflow import get_continuation_prompt
prompt = get_continuation_prompt('issue-to-impl', 'test-session', '/tmp/test.json', 1, 10, plan_path='/tmp/plan.md', plan_excerpt='Step 1: Add feature X')
print('PLAN_EXCERPT_OK' if 'Step 1: Add feature X' in prompt else 'PLAN_EXCERPT_MISSING')
")
[ "$RESULT" = "PLAN_EXCERPT_OK" ] || test_fail "Expected plan_excerpt in issue-to-impl prompt, got '$RESULT'"

test_info "Test 27c: get_continuation_prompt() for issue-to-impl works without plan context"
RESULT=$(run_workflow_python "
from lib.workflow import get_continuation_prompt
prompt = get_continuation_prompt('issue-to-impl', 'test-session', '/tmp/test.json', 1, 10)
# Should still have the base prompt without plan context
print('NO_PLAN_OK' if 'milestone' in prompt.lower() and 'Plan file:' not in prompt else 'NO_PLAN_FAIL')
")
[ "$RESULT" = "NO_PLAN_OK" ] || test_fail "Expected prompt without plan context to still work, got '$RESULT'"

# ============================================================
# Test workflow constants
# ============================================================

test_info "Test 28: ULTRA_PLANNER constant equals 'ultra-planner'"
RESULT=$(run_workflow_python "from lib.workflow import ULTRA_PLANNER; print(ULTRA_PLANNER)")
[ "$RESULT" = "ultra-planner" ] || test_fail "Expected 'ultra-planner', got '$RESULT'"

test_info "Test 29: ISSUE_TO_IMPL constant equals 'issue-to-impl'"
RESULT=$(run_workflow_python "from lib.workflow import ISSUE_TO_IMPL; print(ISSUE_TO_IMPL)")
[ "$RESULT" = "issue-to-impl" ] || test_fail "Expected 'issue-to-impl', got '$RESULT'"

test_info "Test 30: PLAN_TO_ISSUE constant equals 'plan-to-issue'"
RESULT=$(run_workflow_python "from lib.workflow import PLAN_TO_ISSUE; print(PLAN_TO_ISSUE)")
[ "$RESULT" = "plan-to-issue" ] || test_fail "Expected 'plan-to-issue', got '$RESULT'"

test_info "Test 31: SETUP_VIEWBOARD constant equals 'setup-viewboard'"
RESULT=$(run_workflow_python "from lib.workflow import SETUP_VIEWBOARD; print(SETUP_VIEWBOARD)")
[ "$RESULT" = "setup-viewboard" ] || test_fail "Expected 'setup-viewboard', got '$RESULT'"

test_info "Test 32: SYNC_MASTER constant equals 'sync-master'"
RESULT=$(run_workflow_python "from lib.workflow import SYNC_MASTER; print(SYNC_MASTER)")
[ "$RESULT" = "sync-master" ] || test_fail "Expected 'sync-master', got '$RESULT'"

# ============================================================
# Test HANDSOFF_SUPERVISOR provider enum behavior
# ============================================================

test_info "Test 33: HANDSOFF_SUPERVISOR=none disables supervisor (returns None)"
RESULT=$(run_workflow_python_env "HANDSOFF_SUPERVISOR=none" "
from lib.workflow import _ask_claude_for_guidance
result = _ask_claude_for_guidance('ultra-planner', 1, 10)
print('DISABLED' if result is None else 'ENABLED')
")
[ "$RESULT" = "DISABLED" ] || test_fail "Expected supervisor disabled with 'none', got '$RESULT'"

test_info "Test 34: HANDSOFF_SUPERVISOR=claude enables supervisor path"
# We can't actually test the full supervisor path without mocking acw,
# but we can verify the provider is recognized and passes validation
RESULT=$(run_workflow_python_env "HANDSOFF_SUPERVISOR=claude" "
import os
from lib.workflow import _get_supervisor_provider
provider = _get_supervisor_provider()
print(provider if provider else 'NONE')
")
[ "$RESULT" = "claude" ] || test_fail "Expected 'claude', got '$RESULT'"

test_info "Test 35: HANDSOFF_SUPERVISOR=codex sets codex as provider"
RESULT=$(run_workflow_python_env "HANDSOFF_SUPERVISOR=codex" "
from lib.workflow import _get_supervisor_provider
provider = _get_supervisor_provider()
print(provider if provider else 'NONE')
")
[ "$RESULT" = "codex" ] || test_fail "Expected 'codex', got '$RESULT'"

test_info "Test 36: HANDSOFF_SUPERVISOR_MODEL reads model correctly"
RESULT=$(run_workflow_python_env "HANDSOFF_SUPERVISOR=claude HANDSOFF_SUPERVISOR_MODEL=opus" "
from lib.workflow import _get_supervisor_model
model = _get_supervisor_model('claude')
print(model)
")
[ "$RESULT" = "opus" ] || test_fail "Expected 'opus', got '$RESULT'"

test_info "Test 37: HANDSOFF_SUPERVISOR_MODEL uses provider default when not set"
RESULT=$(run_workflow_python_env "HANDSOFF_SUPERVISOR=claude" "
from lib.workflow import _get_supervisor_model
model = _get_supervisor_model('claude')
print(model)
")
[ "$RESULT" = "sonnet" ] || test_fail "Expected default 'sonnet', got '$RESULT'"

test_info "Test 38: HANDSOFF_SUPERVISOR_FLAGS is read correctly"
RESULT=$(HANDSOFF_SUPERVISOR=claude HANDSOFF_SUPERVISOR_FLAGS="--timeout 1800" PYTHONPATH="$PROJECT_ROOT/.claude-plugin" python3 -c "
from lib.workflow import _get_supervisor_flags
flags = _get_supervisor_flags()
print(flags)
")
[ "$RESULT" = "--timeout 1800" ] || test_fail "Expected '--timeout 1800', got '$RESULT'"

test_info "Test 39: HANDSOFF_SUPERVISOR_FLAGS defaults to empty string"
RESULT=$(run_workflow_python_env "HANDSOFF_SUPERVISOR=claude" "
from lib.workflow import _get_supervisor_flags
flags = _get_supervisor_flags()
print('EMPTY' if flags == '' else flags)
")
[ "$RESULT" = "EMPTY" ] || test_fail "Expected empty string, got '$RESULT'"

test_info "Test 40: Legacy HANDSOFF_SUPERVISOR=0 treated as none (backward compat)"
RESULT=$(run_workflow_python_env "HANDSOFF_SUPERVISOR=0" "
from lib.workflow import _get_supervisor_provider
provider = _get_supervisor_provider()
print('DISABLED' if provider is None else provider)
")
[ "$RESULT" = "DISABLED" ] || test_fail "Expected disabled with legacy '0', got '$RESULT'"

test_info "Test 41: Legacy HANDSOFF_SUPERVISOR=1 treated as claude (backward compat)"
RESULT=$(run_workflow_python_env "HANDSOFF_SUPERVISOR=1" "
from lib.workflow import _get_supervisor_provider
provider = _get_supervisor_provider()
print(provider if provider else 'NONE')
")
[ "$RESULT" = "claude" ] || test_fail "Expected 'claude' with legacy '1', got '$RESULT'"

test_pass "Workflow module works correctly"
