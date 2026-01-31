#!/usr/bin/env bash
# Test: acw --silent suppresses provider stderr without hiding acw errors
# Verifies provider stderr suppression, option filtering, and completion updates

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

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "Testing acw --silent behavior"

TMP_DIR=$(make_temp_dir "acw-silent-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create a simple input file
echo "Test prompt" > "$TMP_DIR/input.txt"

# Create a stub claude command that logs args and writes to stderr
cat > "$TMP_DIR/claude" << 'STUB'
#!/usr/bin/env bash

echo "$@" > "$ARGS_LOG_FILE"
echo "provider stdout"
echo "provider stderr" >&2
STUB
chmod +x "$TMP_DIR/claude"

# Prepend our stub directory to PATH so the stub is found first
export PATH="$TMP_DIR:$PATH"
export ARGS_LOG_FILE="$TMP_DIR/args.log"

# Source the acw module
source "$ACW_CLI"

# Test 1: provider stderr is visible without --silent
stderr_output=$(acw claude test-model "$TMP_DIR/input.txt" "$TMP_DIR/output.txt" --max-tokens 5 2>&1 >/dev/null || true)
if ! echo "$stderr_output" | grep -q "provider stderr"; then
    test_fail "Provider stderr was not visible without --silent"
fi
if [ ! -f "$TMP_DIR/output.txt" ]; then
    test_fail "Output file was not created without --silent"
fi

# Test 2: provider stderr is suppressed with --silent
stderr_output=$(acw claude test-model "$TMP_DIR/input.txt" "$TMP_DIR/output-silent.txt" --silent --max-tokens 5 2>&1 >/dev/null || true)
if [ -n "$stderr_output" ]; then
    test_fail "Expected no stderr output with --silent, got: $stderr_output"
fi
if [ ! -f "$TMP_DIR/output-silent.txt" ]; then
    test_fail "Output file was not created with --silent"
fi
if ! grep -q "provider stdout" "$TMP_DIR/output-silent.txt"; then
    test_fail "Output file missing provider stdout with --silent"
fi

# Test 3: --silent is not forwarded to the provider
if [ ! -f "$ARGS_LOG_FILE" ]; then
    test_fail "Provider args log not created"
fi
logged_args=$(cat "$ARGS_LOG_FILE")
if echo "$logged_args" | grep -q -- "--silent"; then
    test_fail "--silent was forwarded to provider"
fi
if ! echo "$logged_args" | grep -q -- "--max-tokens"; then
    test_fail "Provider options were not forwarded"
fi

# Test 4: acw validation errors still appear with --silent
error_output=$(acw unknown-provider test-model "$TMP_DIR/input.txt" "$TMP_DIR/ignored.txt" --silent 2>&1 >/dev/null || true)
if ! echo "$error_output" | grep -q "Unknown provider"; then
    test_fail "Expected unknown provider error even with --silent"
fi

# Test 5: completion includes --silent
options_output=$(acw --complete cli-options)
if ! echo "$options_output" | grep -q "^--silent$"; then
    test_fail "--silent missing from cli-options completion"
fi

test_pass "acw --silent behavior is correct"
