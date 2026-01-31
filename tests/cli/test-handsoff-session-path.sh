#!/usr/bin/env bash
# Test: Handsoff session path with AGENTIZE_HOME and issue_no extraction

# Inlined shared test helpers (former tests/common.sh)
set -e

# ============================================================
# Test isolation: Clear Telegram environment variables
# ============================================================
# Prevents tests from accidentally sending Telegram API requests
# when developer environments have these variables set
unset AGENTIZE_USE_TG TG_API_TOKEN TG_CHAT_ID TG_ALLOWED_USER_IDS TG_APPROVAL_TIMEOUT_SEC TG_POLL_INTERVAL_SEC

# ============================================================
# Project root detection
# ============================================================

# Helper function to get the current project root (current worktree being tested)
# This is different from AGENTIZE_HOME which points to the agentize framework installation
get_project_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Get project root using shell-neutral approach
# For test isolation, always use the current worktree (ignore parent AGENTIZE_HOME)
PROJECT_ROOT="$(get_project_root)"
if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: Cannot determine project root. Run from git repo."
  exit 1
fi

# Export AGENTIZE_HOME for tests - this is the framework installation path
# Tests use the current project root as the framework location
export AGENTIZE_HOME="$PROJECT_ROOT"

TESTS_DIR="$PROJECT_ROOT/tests"

# ============================================================
# Color constants for terminal output
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================
# Test result helpers
# ============================================================

# Print test pass message and exit with success
# Usage: test_pass "message"
test_pass() {
  echo -e "${GREEN}✓ Test passed: $1${NC}"
  exit 0
}

# Print test fail message and exit with failure
# Usage: test_fail "message"
test_fail() {
  echo -e "${RED}✗ Test failed: $1${NC}"
  exit 1
}

# Print test info message
# Usage: test_info "message"
test_info() {
  echo -e "${BLUE}>>> $1${NC}"
}

# ============================================================
# Git environment cleanup
# ============================================================

# Clean all git environment variables to ensure isolated test environment
# Usage: clean_git_env
clean_git_env() {
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
    unset GIT_INDEX_VERSION GIT_COMMON_DIR
}

# ============================================================
# Resource management
# ============================================================

# Create a temporary directory under .tmp and return its path
# Usage: TMP_DIR=$(make_temp_dir "test-name")
make_temp_dir() {
  local test_name="$1"
  local tmp_dir="$PROJECT_ROOT/.tmp/$test_name"
  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  echo "$tmp_dir"
}

# Clean up a directory
# Usage: cleanup_dir "$TMP_DIR"
cleanup_dir() {
  local dir="$1"
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    rm -rf "$dir"
  fi
}

HOOK_SCRIPT="$PROJECT_ROOT/.claude-plugin/hooks/user-prompt-submit.py"

test_info "Handsoff session path and issue_no extraction tests"

# Create temporary directories for test isolation
TMP_DIR=$(make_temp_dir "handsoff-session-test")
CENTRAL_HOME="$TMP_DIR/central"
LOCAL_HOME="$TMP_DIR/local"
mkdir -p "$CENTRAL_HOME" "$LOCAL_HOME"

# Helper: Run user-prompt-submit hook with specified prompt and AGENTIZE_HOME
run_hook() {
    local prompt="$1"
    local session_id="$2"
    local agentize_home="${3:-}"  # Empty means unset

    local input=$(cat <<EOF
{"prompt": "$prompt", "session_id": "$session_id"}
EOF
)

    if [ -n "$agentize_home" ]; then
        HANDSOFF_MODE=1 AGENTIZE_HOME="$agentize_home" python3 "$HOOK_SCRIPT" <<< "$input"
    else
        # Run without AGENTIZE_HOME (in local directory context)
        (cd "$LOCAL_HOME" && unset AGENTIZE_HOME && HANDSOFF_MODE=1 python3 "$HOOK_SCRIPT" <<< "$input")
    fi
}

# Test 1: With AGENTIZE_HOME set, session file created in central location
test_info "Test 1: AGENTIZE_HOME set → central session file"
SESSION_ID_1="test-session-central-1"
run_hook "/issue-to-impl 42" "$SESSION_ID_1" "$CENTRAL_HOME"

STATE_FILE_1="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_1.json"
[ -f "$STATE_FILE_1" ] || test_fail "Session file not created at central path: $STATE_FILE_1"

# Verify issue_no is extracted
ISSUE_NO_1=$(jq -r '.issue_no' "$STATE_FILE_1")
[ "$ISSUE_NO_1" = "42" ] || test_fail "Expected issue_no=42, got '$ISSUE_NO_1'"

# Test 2: Without AGENTIZE_HOME, session file created at repo root (derived from module location)
test_info "Test 2: AGENTIZE_HOME unset → session file at repo root (derived from session_utils.py)"
SESSION_ID_2="test-session-local-2"
run_hook "/issue-to-impl 99" "$SESSION_ID_2" ""

# When AGENTIZE_HOME is unset, get_agentize_home() derives from session_utils.py location
# which resolves to the repo root, not the current working directory
STATE_FILE_2="$PROJECT_ROOT/.tmp/hooked-sessions/$SESSION_ID_2.json"
[ -f "$STATE_FILE_2" ] || test_fail "Session file not created at repo root path: $STATE_FILE_2"

# Verify issue_no is extracted
ISSUE_NO_2=$(jq -r '.issue_no' "$STATE_FILE_2")
[ "$ISSUE_NO_2" = "99" ] || test_fail "Expected issue_no=99, got '$ISSUE_NO_2'"

# Clean up the session file from repo root
rm -f "$STATE_FILE_2"

# Test 3: /ultra-planner with --refine <issue> extracts issue_no
test_info "Test 3: /ultra-planner --refine 123 → issue_no=123"
SESSION_ID_3="test-session-refine-3"
run_hook "/ultra-planner --refine 123" "$SESSION_ID_3" "$CENTRAL_HOME"

STATE_FILE_3="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_3.json"
[ -f "$STATE_FILE_3" ] || test_fail "Session file not created: $STATE_FILE_3"

ISSUE_NO_3=$(jq -r '.issue_no' "$STATE_FILE_3")
[ "$ISSUE_NO_3" = "123" ] || test_fail "Expected issue_no=123, got '$ISSUE_NO_3'"

WORKFLOW_3=$(jq -r '.workflow' "$STATE_FILE_3")
[ "$WORKFLOW_3" = "ultra-planner" ] || test_fail "Expected workflow=ultra-planner, got '$WORKFLOW_3'"

# Test 4: /ultra-planner <feature> without issue number → issue_no absent
test_info "Test 4: /ultra-planner <feature> → issue_no absent"
SESSION_ID_4="test-session-noissue-4"
run_hook "/ultra-planner new feature idea" "$SESSION_ID_4" "$CENTRAL_HOME"

STATE_FILE_4="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_4.json"
[ -f "$STATE_FILE_4" ] || test_fail "Session file not created: $STATE_FILE_4"

ISSUE_NO_4=$(jq -r '.issue_no' "$STATE_FILE_4")
[ "$ISSUE_NO_4" = "null" ] || test_fail "Expected issue_no=null (absent), got '$ISSUE_NO_4'"

# Test 4b: /ultra-planner --from-issue 456 → issue_no=456
test_info "Test 4b: /ultra-planner --from-issue 456 → issue_no=456"
SESSION_ID_4b="test-session-from-issue-4b"
run_hook "/ultra-planner --from-issue 456" "$SESSION_ID_4b" "$CENTRAL_HOME"

STATE_FILE_4b="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_4b.json"
[ -f "$STATE_FILE_4b" ] || test_fail "Session file not created: $STATE_FILE_4b"

ISSUE_NO_4b=$(jq -r '.issue_no' "$STATE_FILE_4b")
[ "$ISSUE_NO_4b" = "456" ] || test_fail "Expected issue_no=456, got '$ISSUE_NO_4b'"

WORKFLOW_4b=$(jq -r '.workflow' "$STATE_FILE_4b")
[ "$WORKFLOW_4b" = "ultra-planner" ] || test_fail "Expected workflow=ultra-planner, got '$WORKFLOW_4b'"

# Test 5: Workflow field is correctly set
test_info "Test 5: workflow field set correctly for issue-to-impl"
WORKFLOW_1=$(jq -r '.workflow' "$STATE_FILE_1")
[ "$WORKFLOW_1" = "issue-to-impl" ] || test_fail "Expected workflow=issue-to-impl, got '$WORKFLOW_1'"

# Test 6: continuation_count starts at 0
test_info "Test 6: continuation_count starts at 0"
COUNT_1=$(jq -r '.continuation_count' "$STATE_FILE_1")
[ "$COUNT_1" = "0" ] || test_fail "Expected continuation_count=0, got '$COUNT_1'"

# Test 7: /setup-viewboard → workflow=setup-viewboard, no issue_no
test_info "Test 7: /setup-viewboard → workflow=setup-viewboard, no issue_no"
SESSION_ID_7="test-session-setup-viewboard-7"
run_hook "/setup-viewboard" "$SESSION_ID_7" "$CENTRAL_HOME"

STATE_FILE_7="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_7.json"
[ -f "$STATE_FILE_7" ] || test_fail "Session file not created: $STATE_FILE_7"

WORKFLOW_7=$(jq -r '.workflow' "$STATE_FILE_7")
[ "$WORKFLOW_7" = "setup-viewboard" ] || test_fail "Expected workflow=setup-viewboard, got '$WORKFLOW_7'"

ISSUE_NO_7=$(jq -r '.issue_no' "$STATE_FILE_7")
[ "$ISSUE_NO_7" = "null" ] || test_fail "Expected issue_no=null (absent), got '$ISSUE_NO_7'"

# Test 7b: /setup-viewboard --org myorg → workflow=setup-viewboard
test_info "Test 7b: /setup-viewboard --org myorg → workflow=setup-viewboard"
SESSION_ID_7b="test-session-setup-viewboard-7b"
run_hook "/setup-viewboard --org myorg" "$SESSION_ID_7b" "$CENTRAL_HOME"

STATE_FILE_7b="$CENTRAL_HOME/.tmp/hooked-sessions/$SESSION_ID_7b.json"
[ -f "$STATE_FILE_7b" ] || test_fail "Session file not created: $STATE_FILE_7b"

WORKFLOW_7b=$(jq -r '.workflow' "$STATE_FILE_7b")
[ "$WORKFLOW_7b" = "setup-viewboard" ] || test_fail "Expected workflow=setup-viewboard, got '$WORKFLOW_7b'"

# Cleanup
cleanup_dir "$TMP_DIR"

test_pass "Handsoff session path and issue_no extraction works correctly"
