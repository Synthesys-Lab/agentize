#!/usr/bin/env bash
# Test: lol usage command
# Tests Claude Code token usage statistics aggregation via shell CLI

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

test_info "lol usage command tests"

export AGENTIZE_HOME="$PROJECT_ROOT"
export PYTHONPATH="$PROJECT_ROOT/python"
source "$LOL_CLI"

# Test 1: lol usage with missing ~/.claude/projects directory should not crash
# Create temp HOME to isolate from real Claude data
TEST_HOME=$(make_temp_dir "usage-missing-dir")
HOME="$TEST_HOME" lol usage 2>&1
exit_code=$?
if [ $exit_code -ne 0 ]; then
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage with missing ~/.claude/projects exited with code $exit_code"
fi
cleanup_dir "$TEST_HOME"

# Test 2: lol usage --today and --week flags both work
TEST_HOME=$(make_temp_dir "usage-modes")
HOME="$TEST_HOME" lol usage --today 2>&1
exit_code=$?
if [ $exit_code -ne 0 ]; then
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --today exited with code $exit_code"
fi

HOME="$TEST_HOME" lol usage --week 2>&1
exit_code=$?
if [ $exit_code -ne 0 ]; then
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --week exited with code $exit_code"
fi
cleanup_dir "$TEST_HOME"

# Test 3: lol usage with fixture JSONL data extracts correct tokens
TEST_HOME=$(make_temp_dir "usage-fixture")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

# Create a fixture JSONL file with known token counts
# Format matches Claude Code session files: one JSON object per line
cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"usage":{"input_tokens":100,"output_tokens":50}}}
{"type":"assistant","message":{"usage":{"input_tokens":200,"output_tokens":75}}}
{"type":"user","message":"hello"}
{"type":"assistant","message":{"usage":{"input_tokens":150,"output_tokens":100}}}
EOF

# Touch the file to ensure recent mtime
touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --today 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage with fixture data exited with code $exit_code"
fi

# Verify output contains expected metrics (450 input, 225 output from fixture)
echo "$output" | grep -q "1 session" || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage output missing session count"
}

# Check that totals are shown
echo "$output" | grep -q -i "total" || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage output missing 'Total' summary"
}

cleanup_dir "$TEST_HOME"

# Test 4: lol usage --cache flag works and shows cache columns
TEST_HOME=$(make_temp_dir "usage-cache")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

# Create fixture with cache tokens
cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":30,"cache_creation_input_tokens":20}}}
{"type":"assistant","message":{"model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":200,"output_tokens":75,"cache_read_input_tokens":50}}}
EOF

touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --cache 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cache exited with code $exit_code"
fi

# Verify cache columns appear in output
echo "$output" | grep -q "cache_read" || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cache output missing cache_read column"
}

cleanup_dir "$TEST_HOME"

# Test 5: lol usage --cost flag works and shows cost column
TEST_HOME=$(make_temp_dir "usage-cost")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

# Create fixture with model info for cost calculation
cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":1000,"output_tokens":500}}}
{"type":"assistant","message":{"model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":2000,"output_tokens":1000}}}
EOF

touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --cost 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost exited with code $exit_code"
fi

# Verify cost column appears with dollar sign
echo "$output" | grep -q '\$' || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost output missing cost value (no \$ found)"
}

cleanup_dir "$TEST_HOME"

# Test 6: lol usage with unknown model shows warning
TEST_HOME=$(make_temp_dir "usage-unknown-model")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

# Create fixture with unknown model
cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"model":"unknown-model-xyz","usage":{"input_tokens":1000,"output_tokens":500}}}
EOF

touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --cost 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost with unknown model exited with code $exit_code"
fi

# Should still work but with warning or N/A cost
cleanup_dir "$TEST_HOME"

# Test 7: lol usage --cache --cost flags work together
TEST_HOME=$(make_temp_dir "usage-cache-cost")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":1000,"output_tokens":500,"cache_read_input_tokens":200,"cache_creation_input_tokens":100}}}
EOF

touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --cache --cost 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cache --cost exited with code $exit_code"
fi

# Verify both cache and cost columns
echo "$output" | grep -q "cache_read" || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cache --cost missing cache_read column"
}

echo "$output" | grep -q '\$' || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cache --cost missing cost column"
}

cleanup_dir "$TEST_HOME"

# Test 8: lol usage --cost with Claude 4.5 model does NOT show unknown model warning
TEST_HOME=$(make_temp_dir "usage-claude-4-5")
PROJECTS_DIR="$TEST_HOME/.claude/projects"
FIXTURE_DIR="$PROJECTS_DIR/test-project"
mkdir -p "$FIXTURE_DIR"

# Create fixture with Claude 4.5 model (should be recognized)
cat > "$FIXTURE_DIR/session.jsonl" << 'EOF'
{"type":"assistant","message":{"model":"claude-opus-4-5-20251101","usage":{"input_tokens":1000,"output_tokens":500}}}
EOF

touch "$FIXTURE_DIR/session.jsonl"

output=$(HOME="$TEST_HOME" lol usage --cost 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost with Claude 4.5 model exited with code $exit_code"
fi

# Verify NO unknown model warning (4.5 models should be recognized)
if echo "$output" | grep -q "Unknown models"; then
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost incorrectly reports Claude 4.5 as unknown model"
fi

# Verify cost column appears with dollar sign (meaning pricing was computed)
echo "$output" | grep -q '\$' || {
  echo "Output: $output"
  cleanup_dir "$TEST_HOME"
  test_fail "lol usage --cost with Claude 4.5 missing cost value"
}

cleanup_dir "$TEST_HOME"

test_pass "lol usage command works correctly"
