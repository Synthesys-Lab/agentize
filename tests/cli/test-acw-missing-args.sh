#!/usr/bin/env bash
# Test: acw validates missing required arguments

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "acw validates missing required arguments"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

# Test with no arguments - should fail with exit code 1
output=$(acw 2>&1 || true)
echo "$output" | grep -qi "usage\|error" || test_fail "No arguments should show usage or error"

# Test with only cli-name - should fail
output=$(acw claude 2>&1 || true)
echo "$output" | grep -qi "missing\|error\|usage" || test_fail "Missing model should show error"

# Test with cli-name and model - should fail (missing input/output)
output=$(acw claude claude-sonnet-4-20250514 2>&1 || true)
echo "$output" | grep -qi "missing\|error\|usage" || test_fail "Missing files should show error"

# Test with cli-name, model, and input - should fail (missing output)
output=$(acw claude claude-sonnet-4-20250514 /tmp/nonexistent.txt 2>&1 || true)
echo "$output" | grep -qi "missing\|error\|usage" || test_fail "Missing output should show error"

# Test with unknown provider - should fail with exit code 2
exit_code=0
output=$(acw unknown-provider model input.txt output.txt 2>&1) || exit_code=$?
[ "$exit_code" -eq 2 ] || test_fail "Unknown provider should return exit code 2, got $exit_code"
echo "$output" | grep -qi "unknown\|unsupported\|provider" || test_fail "Unknown provider should show error"

test_pass "acw validates missing required arguments"
