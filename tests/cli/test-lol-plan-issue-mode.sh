#!/usr/bin/env bash
# Test: lol plan default issue creation and --dry-run skip
# Default behavior creates an issue; --dry-run skips issue creation

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
PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "lol plan default creates issue, --dry-run skips issue creation"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$PLANNER_CLI"
source "$LOL_CLI"

# Create temp directory for test artifacts
TMP_DIR=$(make_temp_dir "test-lol-plan-issue-mode-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# ── gh stub setup ──
GH_CALL_LOG="$TMP_DIR/gh-calls.log"
touch "$GH_CALL_LOG"

# Create gh stub that logs calls and returns a deterministic issue URL
gh() {
    echo "gh $*" >> "$GH_CALL_LOG"

    if [ "$1" = "issue" ] && [ "$2" = "create" ]; then
        # Return issue URL on stdout
        echo "https://github.com/test/repo/issues/42"
        return 0
    elif [ "$1" = "issue" ] && [ "$2" = "view" ]; then
        # Return issue number for --json number query
        if echo "$*" | grep -q "json.*number"; then
            echo '{"number":42}'
            return 0
        fi
        # Return issue body for refine fetch
        if echo "$*" | grep -q "json.*body"; then
            echo "# Implementation Plan: Refinement Seed"
            echo ""
            echo "Refine this plan."
            return 0
        fi
        # Return URL for refine fetch
        if echo "$*" | grep -q "json.*url"; then
            echo "https://github.com/test/repo/issues/42"
            return 0
        fi
        return 0
    elif [ "$1" = "issue" ] && [ "$2" = "edit" ]; then
        return 0
    fi
    return 0
}
export -f gh 2>/dev/null || true

# ── acw stub setup ──
ACW_CALL_LOG="$TMP_DIR/acw-calls.log"
touch "$ACW_CALL_LOG"

acw() {
    local cli_name="$1"
    local model_name="$2"
    local input_file="$3"
    local output_file="$4"

    echo "acw $cli_name $model_name $input_file $output_file" >> "$ACW_CALL_LOG"

    if grep -q "understander\|context-gathering\|Context Summary" "$input_file" 2>/dev/null; then
        echo "# Context Summary: Test Feature" > "$output_file"
    elif grep -q "bold\|innovative\|Bold Proposal" "$input_file" 2>/dev/null; then
        echo "# Bold Proposal: Test Feature" > "$output_file"
    elif grep -q "critique\|Critical\|feasibility" "$input_file" 2>/dev/null; then
        echo "# Proposal Critique: Test Feature" > "$output_file"
    elif grep -q "simplif\|reducer\|less is more" "$input_file" 2>/dev/null; then
        echo "# Simplified Proposal: Test Feature" > "$output_file"
    else
        echo "# Unknown Stage Output" > "$output_file"
    fi
    return 0
}
export -f acw 2>/dev/null || true

# ── Stub consensus script ──
STUB_CONSENSUS_DIR="$TMP_DIR/consensus-stub"
mkdir -p "$STUB_CONSENSUS_DIR"
STUB_CONSENSUS="$STUB_CONSENSUS_DIR/external-consensus.sh"
cat > "$STUB_CONSENSUS" <<'STUBEOF'
#!/usr/bin/env bash
# Derive consensus path from input filenames (issue-{N} or timestamp prefix)
INPUT_BASE=$(basename "$1")
PREFIX="${INPUT_BASE%-*}"
CONSENSUS_FILE=".tmp/${PREFIX}-consensus.md"
mkdir -p .tmp
# Include preamble before the plan header (real consensus files have this)
echo "Using external-consensus skill to synthesize a balanced plan." > "$CONSENSUS_FILE"
echo "" >> "$CONSENSUS_FILE"
echo "# Implementation Plan: Improved Test Feature" >> "$CONSENSUS_FILE"
echo "" >> "$CONSENSUS_FILE"
echo "Stub consensus output" >> "$CONSENSUS_FILE"
echo "$CONSENSUS_FILE"
exit 0
STUBEOF
chmod +x "$STUB_CONSENSUS"
export _PLANNER_CONSENSUS_SCRIPT="$STUB_CONSENSUS"

# ── Test 1: Default behavior creates issue (no --dry-run) ──
output=$(lol plan "Add a test feature for validation" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan (default issue mode) exited with non-zero status"
}

# Verify issue-based artifact naming was used (issue-42 prefix)
echo "$output" | grep -q "issue-42" || {
    echo "Output: $output" >&2
    test_fail "Expected issue-42 artifact prefix in output"
}

# Verify gh issue create was called with placeholder title format
grep -q "gh issue create" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh issue create to be called"
}

# Verify placeholder title uses "[plan][placeholder]" format
grep -q '\[plan\]\[placeholder\]' "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected placeholder title with '[plan][placeholder]' prefix"
}

# Verify gh issue edit --add-label was called for publishing
grep -q "add-label.*agentize:plan" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh issue edit --add-label agentize:plan to be called"
}

# Verify final title was extracted from consensus header (not the raw feature description)
grep -q '\[plan\] \[#42\] Improved Test Feature' "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected final title extracted from consensus 'Implementation Plan:' header with issue prefix"
}

# ── Test 2: --dry-run skips issue creation ──
# Reset logs
> "$GH_CALL_LOG"
> "$ACW_CALL_LOG"

output=$(lol plan --dry-run "Add another test feature" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan --dry-run exited with non-zero status"
}

# Verify NO gh issue create was called
if grep -q "gh issue create" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--dry-run should NOT call gh issue create"
fi

# Verify pipeline still completed (consensus referenced)
echo "$output" | grep -q "consensus\|Consensus" || {
    echo "Output: $output" >&2
    test_fail "Pipeline should still complete with --dry-run"
}

# ── Test 3: --refine uses issue-refine prefix and publishes ──
# Reset logs
> "$GH_CALL_LOG"
> "$ACW_CALL_LOG"

output=$(lol plan --refine 42 "Tighten scope" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan --refine exited with non-zero status"
}

echo "$output" | grep -q "issue-refine-42" || {
    echo "Output: $output" >&2
    test_fail "Expected issue-refine-42 artifact prefix in output"
}

if grep -q "gh issue create" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--refine should NOT create a new issue"
fi

grep -q "gh issue view" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--refine should fetch the existing issue"
}

grep -q "gh issue edit" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--refine should publish updates to the existing issue"
}

# ── Test 4: --dry-run --refine skips publish but keeps issue-refine prefix ──
# Reset logs
> "$GH_CALL_LOG"
> "$ACW_CALL_LOG"

output=$(lol plan --dry-run --refine 42 "Add error cases" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan --dry-run --refine exited with non-zero status"
}

echo "$output" | grep -q "issue-refine-42" || {
    echo "Output: $output" >&2
    test_fail "Expected issue-refine-42 artifact prefix in output (dry-run refine)"
}

if grep -q "gh issue create" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--dry-run --refine should NOT create a new issue"
fi

if grep -q "gh issue edit" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--dry-run --refine should NOT publish updates"
fi

grep -q "gh issue view" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--dry-run --refine should still fetch the issue body"
}

# ── Test 5: Fallback when gh fails (default mode) ──
# Reset logs
> "$GH_CALL_LOG"
> "$ACW_CALL_LOG"

# Override gh to fail
gh() {
    echo "gh $*" >> "$GH_CALL_LOG"
    return 1
}
export -f gh 2>/dev/null || true

output=$(lol plan "Add fallback test feature" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan should not fail when gh fails (fallback to timestamp)"
}

# Verify fallback warning was emitted
echo "$output" | grep -qi "warn\|fallback\|falling back" || {
    echo "Output: $output" >&2
    test_fail "Expected warning about gh failure and timestamp fallback"
}

# Verify pipeline still completed (consensus referenced)
echo "$output" | grep -q "consensus\|Consensus" || {
    echo "Output: $output" >&2
    test_fail "Pipeline should still complete with timestamp fallback"
}

test_pass "lol plan default creates issue, --dry-run skips issue creation"
