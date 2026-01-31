#!/usr/bin/env bash
# Test: wt spawn --headless returns immediately and outputs structured PID:/Log: format

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
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt spawn --headless non-blocking behavior and output format"

# Create claude stub that sleeps (simulates long-running process)
create_claude_stub() {
    cat > bin/claude <<'CLAUDE_STUB'
#!/usr/bin/env bash
# Stub claude that sleeps for a few seconds
sleep 3
echo "Claude completed"
CLAUDE_STUB
    chmod +x bin/claude
}

setup_test_repo
source ./wt-cli.sh

# Create claude stub in PATH
create_claude_stub

# Initialize wt environment
wt init >/dev/null 2>&1 || test_fail "wt init failed"

# Test 1: wt spawn --headless returns in <2 seconds while claude stub sleeps for 3s
cd "$TEST_REPO_DIR"
start_time=$(date +%s)
spawn_output=$(wt spawn 42 --headless 2>&1)
spawn_exit=$?
end_time=$(date +%s)

elapsed=$((end_time - start_time))
if [ $elapsed -ge 2 ]; then
    cleanup_test_repo
    test_fail "wt spawn --headless took ${elapsed}s (should be <2s for non-blocking)"
fi

if [ $spawn_exit -ne 0 ]; then
    cleanup_test_repo
    test_fail "wt spawn 42 --headless failed with exit code $spawn_exit: $spawn_output"
fi

# Test 2: Output contains PID: and Log: lines
pid_line=$(echo "$spawn_output" | grep "^PID: ")
log_line=$(echo "$spawn_output" | grep "^Log: ")

if [ -z "$pid_line" ]; then
    echo "DEBUG: spawn_output = $spawn_output" >&2
    cleanup_test_repo
    test_fail "spawn output should contain 'PID: <number>' line"
fi

if [ -z "$log_line" ]; then
    echo "DEBUG: spawn_output = $spawn_output" >&2
    cleanup_test_repo
    test_fail "spawn output should contain 'Log: <path>' line"
fi

# Test 3: PID is a valid number and process is alive
pid=$(echo "$pid_line" | sed 's/^PID: //')
if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
    cleanup_test_repo
    test_fail "PID should be a number, got: $pid"
fi

if ! kill -0 "$pid" 2>/dev/null; then
    cleanup_test_repo
    test_fail "PID $pid should be alive immediately after spawn"
fi

# Test 4: Log file exists at printed path
log_path=$(echo "$log_line" | sed 's/^Log: //')
if [ ! -f "$log_path" ]; then
    cleanup_test_repo
    test_fail "Log file should exist at: $log_path"
fi

# Clean up: kill the stubbed claude process
kill "$pid" 2>/dev/null || true

cleanup_test_repo
test_pass "wt spawn --headless is non-blocking with structured PID:/Log: output"
