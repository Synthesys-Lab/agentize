#!/usr/bin/env bash
# Test: lol plan --editor flag functionality

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

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol plan --editor flag functionality"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Create isolated test home
TEST_HOME=$(make_temp_dir "test-home-$$")
export HOME="$TEST_HOME"

# Test 1: Error when EDITOR is unset
unset EDITOR

set +e
output=$(_lol_parse_plan --editor 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should fail when EDITOR is unset"
fi

if ! echo "$output" | grep -q "EDITOR is not set"; then
  test_fail "--editor error message should mention EDITOR is not set"
fi

# Test 2: Error when --editor is combined with positional argument
export EDITOR="cat"

set +e
output=$(_lol_parse_plan --editor "positional description" 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should be mutually exclusive with positional argument"
fi

if ! echo "$output" | grep -qi "cannot\|both"; then
  test_fail "--editor mutual exclusion error should be clear"
fi

# Test 3: Editor writes content and it's used as feature description
# Create a stub editor that writes content to the file
STUB_EDITOR="$TEST_HOME/stub-editor.sh"
cat > "$STUB_EDITOR" << 'STUB'
#!/usr/bin/env bash
echo "Feature description from editor" > "$1"
STUB
chmod +x "$STUB_EDITOR"

export EDITOR="$STUB_EDITOR"

# Mock _lol_cmd_plan to capture what it receives
captured_desc=""
_lol_cmd_plan() {
  captured_desc="$1"
  return 0
}

set +e
_lol_parse_plan --editor --dry-run
exit_code=$?
set -e

if [ "$exit_code" -ne 0 ]; then
  test_fail "--editor with valid editor should succeed"
fi

if [ "$captured_desc" != "Feature description from editor" ]; then
  test_fail "Feature description should come from editor content, got: '$captured_desc'"
fi

# Test 4: Empty file or whitespace-only content is rejected
EMPTY_EDITOR="$TEST_HOME/empty-editor.sh"
cat > "$EMPTY_EDITOR" << 'STUB'
#!/usr/bin/env bash
echo "   " > "$1"
STUB
chmod +x "$EMPTY_EDITOR"

export EDITOR="$EMPTY_EDITOR"

set +e
output=$(_lol_parse_plan --editor 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should reject empty/whitespace-only content"
fi

if ! echo "$output" | grep -qi "empty"; then
  test_fail "--editor empty content error should mention 'empty'"
fi

# Test 5: Non-zero editor exit aborts
FAIL_EDITOR="$TEST_HOME/fail-editor.sh"
cat > "$FAIL_EDITOR" << 'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$FAIL_EDITOR"

export EDITOR="$FAIL_EDITOR"

set +e
output=$(_lol_parse_plan --editor 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
  test_fail "--editor should fail when editor exits non-zero"
fi

test_pass "lol plan --editor flag works correctly"
