#!/usr/bin/env bash
# Test: Session utilities module - session_dir() function
# Purpose: Verify shared session_dir() function works correctly with different configurations

source "$(dirname "$0")/../common.sh"

test_info "Session utilities module tests"

# Create temporary directory for test isolation
TMP_DIR=$(make_temp_dir "session-utils-test")
CUSTOM_HOME="$TMP_DIR/custom-home"
mkdir -p "$CUSTOM_HOME"

# Helper: Run Python code that imports and tests session_utils
run_session_utils_test() {
    local test_code="$1"
    local agentize_home="${2:-}"

    local python_code="
import sys
from pathlib import Path

# Add .claude-plugin to path
plugin_dir = Path('$PROJECT_ROOT/.claude-plugin')
sys.path.insert(0, str(plugin_dir))

from lib.session_utils import session_dir

$test_code
"

    if [ -n "$agentize_home" ]; then
        AGENTIZE_HOME="$agentize_home" python3 -c "$python_code"
    else
        (cd "$TMP_DIR" && unset AGENTIZE_HOME && python3 -c "$python_code")
    fi
}

# Test 1: Default behavior returns ./.tmp/hooked-sessions
test_info "Test 1: Default behavior (AGENTIZE_HOME unset) → ./.tmp/hooked-sessions"
RESULT_1=$(run_session_utils_test "print(session_dir())" "")
[ "$RESULT_1" = "./.tmp/hooked-sessions" ] || test_fail "Expected './.tmp/hooked-sessions', got '$RESULT_1'"

# Test 2: With AGENTIZE_HOME set, returns custom path
test_info "Test 2: AGENTIZE_HOME set → custom path"
RESULT_2=$(run_session_utils_test "print(session_dir())" "$CUSTOM_HOME")
[ "$RESULT_2" = "$CUSTOM_HOME/.tmp/hooked-sessions" ] || test_fail "Expected '$CUSTOM_HOME/.tmp/hooked-sessions', got '$RESULT_2'"

# Test 3: makedirs=False (default) does not create directories
test_info "Test 3: makedirs=False (default) → directories not created"
NON_EXISTENT_HOME="$TMP_DIR/nonexistent"
rm -rf "$NON_EXISTENT_HOME"
run_session_utils_test "path = session_dir(); print(path)" "$NON_EXISTENT_HOME"
[ ! -d "$NON_EXISTENT_HOME/.tmp/hooked-sessions" ] || test_fail "Directories should not be created with makedirs=False"

# Test 4: makedirs=True creates directories
test_info "Test 4: makedirs=True → directories created"
MAKEDIRS_HOME="$TMP_DIR/makedirs-home"
rm -rf "$MAKEDIRS_HOME"
run_session_utils_test "path = session_dir(makedirs=True); print(path)" "$MAKEDIRS_HOME"
[ -d "$MAKEDIRS_HOME/.tmp/hooked-sessions" ] || test_fail "Directories should be created with makedirs=True"

# Test 5: Return type is string (not Path object)
test_info "Test 5: Return type is str"
RESULT_5=$(run_session_utils_test "print(type(session_dir()).__name__)" "$CUSTOM_HOME")
[ "$RESULT_5" = "str" ] || test_fail "Expected return type 'str', got '$RESULT_5'"

# Cleanup
cleanup_dir "$TMP_DIR"

test_pass "Session utilities module works correctly"
