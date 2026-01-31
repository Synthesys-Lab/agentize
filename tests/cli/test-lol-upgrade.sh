#!/usr/bin/env bash
# Test: lol upgrade runs make setup after successful git pull

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

test_info "lol upgrade runs make setup after successful git pull"

# Create temp directory for test environment
TMP_DIR=$(make_temp_dir "test-lol-upgrade")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create mock AGENTIZE_HOME with git repo
MOCK_AGENTIZE_HOME="$TMP_DIR/agentize"
mkdir -p "$MOCK_AGENTIZE_HOME"
git -C "$MOCK_AGENTIZE_HOME" init -q
git -C "$MOCK_AGENTIZE_HOME" config user.email "test@test.com"
git -C "$MOCK_AGENTIZE_HOME" config user.name "Test"
touch "$MOCK_AGENTIZE_HOME/README.md"
git -C "$MOCK_AGENTIZE_HOME" add .
git -C "$MOCK_AGENTIZE_HOME" commit -q -m "Initial commit"

# Create a simple Makefile with setup target that creates a marker file
cat > "$MOCK_AGENTIZE_HOME/Makefile" << 'MAKEFILE'
.PHONY: setup
setup:
	@touch setup-was-called.marker
	@echo "Setup completed"
MAKEFILE

# Commit Makefile to avoid dirty-tree guard
git -C "$MOCK_AGENTIZE_HOME" add Makefile
git -C "$MOCK_AGENTIZE_HOME" commit -q -m "Add Makefile"

# Set origin to self (so git pull works)
git -C "$MOCK_AGENTIZE_HOME" remote add origin "$MOCK_AGENTIZE_HOME"
git -C "$MOCK_AGENTIZE_HOME" fetch -q origin 2>/dev/null || true

# Create origin/main branch for pull to succeed
git -C "$MOCK_AGENTIZE_HOME" branch -M main
git -C "$MOCK_AGENTIZE_HOME" symbolic-ref refs/remotes/origin/HEAD refs/heads/main 2>/dev/null || true

# Set up environment
export AGENTIZE_HOME="$MOCK_AGENTIZE_HOME"
source "$LOL_CLI"

# Test 1: Verify make setup is called after git pull
test_info "Test 1: make setup is called after successful git pull"

# Remove any existing marker
rm -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker"

# Run upgrade
output=$(lol upgrade 2>&1) || true

# Check if make setup was called (marker file should exist)
if [ ! -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker" ]; then
    echo "Output:"
    echo "$output"
    test_fail "make setup was not executed - marker file missing"
fi

# Test 2: Verify output mentions setup completion
test_info "Test 2: output mentions upgrade success"

if ! echo "$output" | grep -qi "upgrade\|success"; then
    echo "Output:"
    echo "$output"
    test_fail "Output should mention successful upgrade"
fi

# Test 3: Verify shell reload instructions are displayed
test_info "Test 3: shell reload instructions are displayed"

if ! echo "$output" | grep -q "reload\|exec"; then
    echo "Output:"
    echo "$output"
    test_fail "Output should include shell reload instructions"
fi

# Test 4: Verify claude plugin update is called when claude is available
test_info "Test 4: claude plugin update is called when claude is available"

# Create a mock claude binary that logs its arguments
MOCK_BIN_DIR="$TMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN_DIR"
CLAUDE_LOG="$TMP_DIR/claude-calls.log"
cat > "$MOCK_BIN_DIR/claude" << 'MOCKEOF'
#!/usr/bin/env bash
echo "$@" >> "$(dirname "$0")/../claude-calls.log"
exit 0
MOCKEOF
chmod +x "$MOCK_BIN_DIR/claude"

# Prepend mock bin to PATH so `command -v claude` finds our mock
export PATH="$MOCK_BIN_DIR:$PATH"

# Remove stale marker and re-run upgrade
rm -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker"
rm -f "$CLAUDE_LOG"

output=$(_lol_cmd_upgrade 2>&1) || true

# Check that claude was called with plugin update arguments
if [ ! -f "$CLAUDE_LOG" ]; then
    echo "Output:"
    echo "$output"
    test_fail "claude was not called at all during upgrade"
fi

if ! grep -q "plugin.*update\|plugin.*marketplace" "$CLAUDE_LOG"; then
    echo "Claude calls:"
    cat "$CLAUDE_LOG"
    test_fail "claude was not called with plugin update arguments"
fi

# Test 5: Verify upgrade succeeds when claude is NOT available
test_info "Test 5: upgrade succeeds when claude is not available"

# Remove mock claude from PATH
export PATH="${PATH#$MOCK_BIN_DIR:}"

# Remove stale marker
rm -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker"

output=$(_lol_cmd_upgrade 2>&1) || true

# Upgrade should still succeed (make setup marker should exist)
if [ ! -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker" ]; then
    echo "Output:"
    echo "$output"
    test_fail "upgrade failed when claude is not available"
fi

test_pass "lol upgrade correctly runs make setup and optional plugin update"
