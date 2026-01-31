#!/usr/bin/env bash
# Test: acw --yolo translation for Claude provider
# Verifies that --yolo is translated to --dangerously-skip-permissions when invoking Claude

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

test_info "Testing --yolo translation for Claude provider"

# Create temp directory for test artifacts
TMP_DIR=$(make_temp_dir "acw-yolo-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create a simple input file
echo "Test prompt" > "$TMP_DIR/input.txt"

# Create a stub claude command that logs its arguments
cat > "$TMP_DIR/claude" << 'STUB'
#!/usr/bin/env bash
# Log all arguments to a file for verification
echo "$@" > "$ARGS_LOG_FILE"
# Write dummy output
echo "stub response"
STUB
chmod +x "$TMP_DIR/claude"

# Prepend our stub directory to PATH so the stub is found first
export PATH="$TMP_DIR:$PATH"
export ARGS_LOG_FILE="$TMP_DIR/args.log"
export AGENTIZE_HOME="$PROJECT_ROOT"

# Source the acw module
source "$ACW_CLI"

# Test: invoke acw with claude and --yolo flag
test_info "Invoking acw claude with --yolo flag"
acw claude test-model "$TMP_DIR/input.txt" "$TMP_DIR/output.txt" --yolo

# Check if the args log contains --dangerously-skip-permissions instead of --yolo
if [ ! -f "$ARGS_LOG_FILE" ]; then
    test_fail "Claude stub was not invoked - args log file missing"
fi

logged_args=$(cat "$ARGS_LOG_FILE")
test_info "Logged args: $logged_args"

if echo "$logged_args" | grep -q -- "--yolo"; then
    test_fail "--yolo was passed directly to Claude instead of being translated"
fi

if ! echo "$logged_args" | grep -q -- "--dangerously-skip-permissions"; then
    test_fail "--yolo was not translated to --dangerously-skip-permissions"
fi

test_pass "--yolo correctly translated to --dangerously-skip-permissions for Claude"
