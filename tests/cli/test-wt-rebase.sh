#!/usr/bin/env bash
# Test: wt rebase command basic functionality

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

WT_CLI="$PROJECT_ROOT/src/cli/wt.sh"

test_info "wt rebase command basic functionality"

# Setup test repo
setup_test_repo

# Initialize worktree environment
source "$WT_CLI"
wt init >/dev/null 2>&1

# Test 1: Missing PR number returns error
output=$(wt rebase 2>&1) || true
if ! echo "$output" | grep -qi "missing\|usage\|error"; then
  test_fail "wt rebase without PR number should show error"
fi

# Test 2: Non-numeric PR number returns error
output=$(wt rebase abc 2>&1) || true
if ! echo "$output" | grep -qi "numeric\|error"; then
  test_fail "wt rebase with non-numeric PR should show error"
fi

# Test 3: Unknown flag returns error
output=$(wt rebase 123 --unknown-flag 2>&1) || true
if ! echo "$output" | grep -qi "unknown\|error"; then
  test_fail "wt rebase with unknown flag should show error"
fi

# Test 4: --headless flag is parsed (doesn't fail due to flag parsing)
# This tests that the flag parsing works; actual rebase requires gh CLI mocking
output=$(wt rebase --headless 123 2>&1) || true
# Should fail for PR not found, not for flag parsing
if echo "$output" | grep -qi "unknown flag"; then
  test_fail "wt rebase --headless should be a valid flag"
fi

# Test 5: --yolo flag is parsed (doesn't fail due to flag parsing)
output=$(wt rebase --yolo 123 2>&1) || true
# Should fail for PR not found, not for flag parsing
if echo "$output" | grep -qi "unknown flag"; then
  test_fail "wt rebase --yolo should be a valid flag"
fi

# Test 6: rebase command exists in completion
output=$(wt --complete commands 2>/dev/null)
if ! echo "$output" | grep -q "^rebase$"; then
  test_fail "rebase should be in wt --complete commands"
fi

# Test 7: rebase-flags topic exists in completion
output=$(wt --complete rebase-flags 2>/dev/null)
if ! echo "$output" | grep -q "^--headless$"; then
  test_fail "--headless should be in wt --complete rebase-flags"
fi

if ! echo "$output" | grep -q "^--yolo$"; then
  test_fail "--yolo should be in wt --complete rebase-flags"
fi

# Cleanup
cleanup_test_repo

test_pass "wt rebase command basic functionality"
