#!/usr/bin/env bash
# Test: session_utils helper functions (is_handsoff_enabled, write_issue_index)

source "$(dirname "$0")/../common.sh"

test_info "Session utils helper function tests"

# Create temporary directory for test isolation
TMP_DIR=$(make_temp_dir "session-utils-test")

# Helper: Run Python code with .claude-plugin in PYTHONPATH
run_python() {
    PYTHONPATH="$PROJECT_ROOT/.claude-plugin" python3 -c "$1"
}

# ============================================================
# Test is_handsoff_enabled()
# ============================================================

test_info "Test 1: HANDSOFF_MODE unset → returns True (enabled by default)"
RESULT=$(unset HANDSOFF_MODE && run_python "from lib.session_utils import is_handsoff_enabled; print(is_handsoff_enabled())")
[ "$RESULT" = "True" ] || test_fail "Expected True when HANDSOFF_MODE unset, got '$RESULT'"

test_info "Test 2: HANDSOFF_MODE=1 → returns True"
RESULT=$(HANDSOFF_MODE=1 run_python "from lib.session_utils import is_handsoff_enabled; print(is_handsoff_enabled())")
[ "$RESULT" = "True" ] || test_fail "Expected True for HANDSOFF_MODE=1, got '$RESULT'"

test_info "Test 3: HANDSOFF_MODE=0 → returns False"
RESULT=$(HANDSOFF_MODE=0 run_python "from lib.session_utils import is_handsoff_enabled; print(is_handsoff_enabled())")
[ "$RESULT" = "False" ] || test_fail "Expected False for HANDSOFF_MODE=0, got '$RESULT'"

test_info "Test 4: HANDSOFF_MODE=false → returns False"
RESULT=$(HANDSOFF_MODE=false run_python "from lib.session_utils import is_handsoff_enabled; print(is_handsoff_enabled())")
[ "$RESULT" = "False" ] || test_fail "Expected False for HANDSOFF_MODE=false, got '$RESULT'"

test_info "Test 5: HANDSOFF_MODE=FALSE → returns False (case-insensitive)"
RESULT=$(HANDSOFF_MODE=FALSE run_python "from lib.session_utils import is_handsoff_enabled; print(is_handsoff_enabled())")
[ "$RESULT" = "False" ] || test_fail "Expected False for HANDSOFF_MODE=FALSE, got '$RESULT'"

test_info "Test 6: HANDSOFF_MODE=off → returns False"
RESULT=$(HANDSOFF_MODE=off run_python "from lib.session_utils import is_handsoff_enabled; print(is_handsoff_enabled())")
[ "$RESULT" = "False" ] || test_fail "Expected False for HANDSOFF_MODE=off, got '$RESULT'"

test_info "Test 7: HANDSOFF_MODE=disable → returns False"
RESULT=$(HANDSOFF_MODE=disable run_python "from lib.session_utils import is_handsoff_enabled; print(is_handsoff_enabled())")
[ "$RESULT" = "False" ] || test_fail "Expected False for HANDSOFF_MODE=disable, got '$RESULT'"

test_info "Test 8: HANDSOFF_MODE=yes → returns True (not in disabled list)"
RESULT=$(HANDSOFF_MODE=yes run_python "from lib.session_utils import is_handsoff_enabled; print(is_handsoff_enabled())")
[ "$RESULT" = "True" ] || test_fail "Expected True for HANDSOFF_MODE=yes, got '$RESULT'"

# ============================================================
# Test write_issue_index()
# ============================================================

test_info "Test 9: write_issue_index creates correct JSON file"
SESS_DIR="$TMP_DIR/sess"
mkdir -p "$SESS_DIR"

PYTHONPATH="$PROJECT_ROOT/.claude-plugin" python3 << EOF
from lib.session_utils import write_issue_index
result = write_issue_index("test-session-123", 42, "issue-to-impl", sess_dir="$SESS_DIR")
print(result)
EOF

INDEX_FILE="$SESS_DIR/by-issue/42.json"
[ -f "$INDEX_FILE" ] || test_fail "Index file not created at $INDEX_FILE"

# Verify JSON content
SESSION_ID=$(jq -r '.session_id' "$INDEX_FILE")
WORKFLOW=$(jq -r '.workflow' "$INDEX_FILE")
[ "$SESSION_ID" = "test-session-123" ] || test_fail "Expected session_id=test-session-123, got '$SESSION_ID'"
[ "$WORKFLOW" = "issue-to-impl" ] || test_fail "Expected workflow=issue-to-impl, got '$WORKFLOW'"

test_info "Test 10: write_issue_index with string issue number"
PYTHONPATH="$PROJECT_ROOT/.claude-plugin" python3 << EOF
from lib.session_utils import write_issue_index
write_issue_index("test-session-456", "99", "ultra-planner", sess_dir="$SESS_DIR")
EOF

INDEX_FILE_99="$SESS_DIR/by-issue/99.json"
[ -f "$INDEX_FILE_99" ] || test_fail "Index file not created for issue 99"

SESSION_ID_99=$(jq -r '.session_id' "$INDEX_FILE_99")
[ "$SESSION_ID_99" = "test-session-456" ] || test_fail "Expected session_id=test-session-456, got '$SESSION_ID_99'"

test_info "Test 11: write_issue_index returns correct path"
RETURNED_PATH=$(PYTHONPATH="$PROJECT_ROOT/.claude-plugin" python3 << EOF
from lib.session_utils import write_issue_index
print(write_issue_index("test-session-789", 100, "plan-to-issue", sess_dir="$SESS_DIR"))
EOF
)

EXPECTED_PATH="$SESS_DIR/by-issue/100.json"
[ "$RETURNED_PATH" = "$EXPECTED_PATH" ] || test_fail "Expected path $EXPECTED_PATH, got '$RETURNED_PATH'"

# Cleanup
cleanup_dir "$TMP_DIR"

test_pass "Session utils helper functions work correctly"
