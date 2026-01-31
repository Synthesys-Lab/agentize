#!/usr/bin/env bash
# Test: wt --complete goto-targets outputs bare issue numbers, not issue-<N>

# Shared test helpers
set -e
SCRIPT_PATH="$0"
if [ -n "${BASH_SOURCE[0]-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
if [ "${SCRIPT_PATH%/*}" = "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="."
else
  SCRIPT_DIR="${SCRIPT_PATH%/*}"
fi
source "$SCRIPT_DIR/../common.sh"

source "$SCRIPT_DIR/../helpers-worktree.sh"

test_info "wt --complete goto-targets outputs bare issue numbers"

# Setup test repository
setup_test_repo

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$TEST_REPO_DIR/wt-cli.sh"

# Initialize worktrees structure
wt init >/dev/null 2>&1

# Spawn issue-42 worktree
wt spawn 42 --no-agent >/dev/null 2>&1

# Get output from wt --complete goto-targets
output=$(wt --complete goto-targets 2>/dev/null)

# Verify 'main' is present
echo "$output" | grep -q "^main$" || test_fail "Missing target: main"

# Verify bare issue number '42' is present
echo "$output" | grep -q "^42$" || test_fail "Missing target: 42 (bare issue number)"

# CRITICAL: Verify 'issue-42' is NOT present (guards the doc format)
if echo "$output" | grep -q "^issue-42"; then
  test_fail "Output should be bare numbers (42), not prefixed (issue-42)"
fi

# Cleanup
cleanup_test_repo

test_pass "wt --complete goto-targets outputs correct format"
