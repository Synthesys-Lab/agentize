#!/usr/bin/env bash
# Test: external-consensus.sh 3-report-path argument parsing

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

# Override PROJECT_ROOT to use current worktree instead of AGENTIZE_HOME
PROJECT_ROOT=$(git rev-parse --show-toplevel)

test_info "Testing external-consensus.sh argument parsing for 3-report-path mode"

# Setup: Create test agent reports
ISSUE_NUMBER=42
REPORT1_FILE="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-bold-proposal.md"
REPORT2_FILE="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-critique.md"
REPORT3_FILE="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-reducer.md"

mkdir -p "$PROJECT_ROOT/.tmp"
cat > "$REPORT1_FILE" << 'EOF'
# Bold Proposer Report

**Feature**: Test Feature

This is a bold proposal for the test feature.
EOF

cat > "$REPORT2_FILE" << 'EOF'
# Critique Report

This is a critique of the bold proposal.
EOF

cat > "$REPORT3_FILE" << 'EOF'
# Reducer Report

This is a simplified version of the proposal.
EOF

# Test Case 1: Verify script requires exactly 3 arguments
test_info "Test 1: Script requires exactly 3 arguments"

if "$PROJECT_ROOT/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh" "$REPORT1_FILE" "$REPORT2_FILE" 2>&1 | grep -q "Error: Exactly 3 report paths are required"; then
    test_info "✓ Script correctly rejects 2 arguments"
else
    test_fail "Script should reject 2 arguments"
fi

if "$PROJECT_ROOT/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh" "$REPORT1_FILE" 2>&1 | grep -q "Error: Exactly 3 report paths are required"; then
    test_info "✓ Script correctly rejects 1 argument"
else
    test_fail "Script should reject 1 argument"
fi

# Test Case 2: Verify script accepts 3 valid report paths
test_info "Test 2: Script accepts 3 valid report paths"

# The script should accept 3 valid paths and proceed to combining them
# We verify this by checking that it doesn't fail with "required" error
if timeout 2 "$PROJECT_ROOT/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh" "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 | grep -q "Error: Exactly 3 report paths are required"; then
    test_fail "Script rejected valid 3-argument invocation"
fi

test_info "✓ Script accepted 3 valid report paths"

# Test Case 3: Verify script validates all 3 files exist
test_info "Test 3: Script validates all report files exist"

MISSING_REPORT="$PROJECT_ROOT/.tmp/missing-report.md"
rm -f "$MISSING_REPORT"

if "$PROJECT_ROOT/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh" "$REPORT1_FILE" "$MISSING_REPORT" "$REPORT3_FILE" 2>&1 | grep -q "Error: Report file not found: $MISSING_REPORT"; then
    test_info "✓ Script correctly detects missing second report"
else
    test_fail "Expected error for missing report file"
fi

# Test Case 4: Verify script creates combined debate report
test_info "Test 4: Script combines reports into debate report"

# Pre-clean the debate report to ensure it's created fresh
DEBATE_REPORT="$PROJECT_ROOT/.tmp/issue-${ISSUE_NUMBER}-debate.md"
rm -f "$DEBATE_REPORT"

# Run the script in background and kill it after debate report creation
# The script will continue to external review, but we only care about the debate report
(
    "$PROJECT_ROOT/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) &
SCRIPT_PID=$!

# Wait up to 5 seconds for the debate report to be created
for i in {1..10}; do
    if [ -f "$DEBATE_REPORT" ]; then
        break
    fi
    sleep 0.5
done

# Kill the script process (it would be trying to invoke Codex/Claude)
kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true

# Verify the debate report was created
if [ -f "$DEBATE_REPORT" ]; then
    test_info "✓ Debate report file created at expected path"

    # Verify it contains content from all 3 reports
    if grep -q "Bold Proposer Report" "$DEBATE_REPORT" && \
       grep -q "Critique Report" "$DEBATE_REPORT" && \
       grep -q "Reducer Report" "$DEBATE_REPORT"; then
        test_info "✓ Debate report contains all 3 agent reports"
    else
        test_fail "Debate report missing content from one or more reports"
    fi
else
    test_fail "Debate report file not created"
fi

# Test Case 5: Usage message documents 3-path requirement
test_info "Test 5: Usage message documents 3-path requirement"

if "$PROJECT_ROOT/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh" 2>&1 | grep -q "<path-to-report1> <path-to-report2> <path-to-report3>"; then
    test_info "✓ Usage message documents 3-path requirement"
else
    test_fail "Usage message missing 3-path documentation"
fi

# Test Case 6: Feature name extraction from header format
test_info "Test 6: Extract feature name from header format"

cat > "$REPORT1_FILE" << 'EOF'
# Bold Proposer Report

# Feature: Header Format Feature

This is a bold proposal for the test feature.
EOF

rm -f "$DEBATE_REPORT"

(
    "$PROJECT_ROOT/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) &
SCRIPT_PID=$!

for i in {1..10}; do
    if [ -f "$DEBATE_REPORT" ]; then
        break
    fi
    sleep 0.5
done

kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true

if [ -f "$DEBATE_REPORT" ]; then
    if grep -q "# Multi-Agent Debate Report: Header Format Feature" "$DEBATE_REPORT"; then
        test_info "✓ Feature name extracted from header format"
    else
        test_fail "Feature name not extracted from header format (expected 'Header Format Feature' in debate report header)"
    fi
else
    test_fail "Debate report not created for header format test"
fi

# Test Case 7: Feature name extraction from plain label format
test_info "Test 7: Extract feature name from plain label format"

cat > "$REPORT1_FILE" << 'EOF'
# Bold Proposer Report

Feature: Plain Label Feature

This is a bold proposal for the test feature.
EOF

rm -f "$DEBATE_REPORT"

(
    "$PROJECT_ROOT/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) &
SCRIPT_PID=$!

for i in {1..10}; do
    if [ -f "$DEBATE_REPORT" ]; then
        break
    fi
    sleep 0.5
done

kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true

if [ -f "$DEBATE_REPORT" ]; then
    if grep -q "# Multi-Agent Debate Report: Plain Label Feature" "$DEBATE_REPORT"; then
        test_info "✓ Feature name extracted from plain label format"
    else
        test_fail "Feature name not extracted from plain label format (expected 'Plain Label Feature' in debate report header)"
    fi
else
    test_fail "Debate report not created for plain label test"
fi

# Test Case 8: Feature name extraction from "Title" label variant
test_info "Test 8: Extract feature name from Title label variant"

cat > "$REPORT1_FILE" << 'EOF'
# Bold Proposer Report

**Title**: Title Variant Feature

This is a bold proposal for the test feature.
EOF

rm -f "$DEBATE_REPORT"

(
    "$PROJECT_ROOT/.claude-plugin/skills/external-consensus/scripts/external-consensus.sh" \
        "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" 2>&1 || true
) &
SCRIPT_PID=$!

for i in {1..10}; do
    if [ -f "$DEBATE_REPORT" ]; then
        break
    fi
    sleep 0.5
done

kill -9 $SCRIPT_PID 2>/dev/null || true
wait $SCRIPT_PID 2>/dev/null || true

if [ -f "$DEBATE_REPORT" ]; then
    if grep -q "# Multi-Agent Debate Report: Title Variant Feature" "$DEBATE_REPORT"; then
        test_info "✓ Feature name extracted from Title label variant"
    else
        test_fail "Feature name not extracted from Title label (expected 'Title Variant Feature' in debate report header)"
    fi
else
    test_fail "Debate report not created for Title label test"
fi

# Cleanup
rm -f "$REPORT1_FILE" "$REPORT2_FILE" "$REPORT3_FILE" "$DEBATE_REPORT"
pkill -9 -f "codex exec" 2>/dev/null || true

test_pass "All external-consensus argument parsing tests passed"
