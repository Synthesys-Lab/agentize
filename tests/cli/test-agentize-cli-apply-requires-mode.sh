#!/usr/bin/env bash
# Test: lol apply requires exactly one of --init or --update

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol apply requires exactly one of --init or --update"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Test 1: Missing both --init and --update should fail with usage hint
exit_code=0
output=$(lol apply 2>&1) || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  test_fail "lol apply without mode flags should fail"
fi

echo "$output" | grep -q -i "init\|update" || test_fail "Error message should mention --init or --update"

# Test 2: Both --init and --update should fail
exit_code=0
output=$(lol apply --init --update 2>&1) || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  test_fail "lol apply with both --init and --update should fail"
fi

echo "$output" | grep -q -i "cannot\|both\|one" || test_fail "Error message should indicate conflict"

test_pass "lol apply requires exactly one mode flag"
