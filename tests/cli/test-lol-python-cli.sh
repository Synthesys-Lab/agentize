#!/usr/bin/env bash
# Test: python -m agentize.cli entrypoint
# Tests the Python CLI wrapper for lol commands

source "$(dirname "$0")/../common.sh"

test_info "python -m agentize.cli entrypoint tests"

export AGENTIZE_HOME="$PROJECT_ROOT"
export PYTHONPATH="$PROJECT_ROOT/python"

# Test 1: --complete commands returns expected list (apply command removed)
output=$(python3 -m agentize.cli --complete commands 2>&1)
echo "$output" | grep -q "^upgrade$" || test_fail "--complete commands missing: upgrade"
echo "$output" | grep -q "^project$" || test_fail "--complete commands missing: project"
echo "$output" | grep -q "^claude-clean$" || test_fail "--complete commands missing: claude-clean"
# Verify apply command is NOT in commands list (it has been removed)
if echo "$output" | grep -q "^apply$"; then
  test_fail "apply command should have been removed"
fi

# Test 2: --version exits 0 and prints expected labels
output=$(python3 -m agentize.cli --version 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  test_fail "--version exited with code $exit_code"
fi
echo "$output" | grep -q "Installation:" || test_fail "--version missing 'Installation:' label"
echo "$output" | grep -q "Last update:" || test_fail "--version missing 'Last update:' label"

test_pass "python -m agentize.cli entrypoint works correctly"
