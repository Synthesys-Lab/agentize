#!/usr/bin/env bash
# Test: lol serve validates required arguments

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol serve validates required arguments"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Test 1: Missing both required arguments
output=$(lol serve 2>&1) || true
if ! echo "$output" | grep -q "Error: --tg-token is required"; then
  test_fail "Should require --tg-token argument"
fi

# Test 2: Missing --tg-chat-id
output=$(lol serve --tg-token=xxx 2>&1) || true
if ! echo "$output" | grep -q "Error: --tg-chat-id is required"; then
  test_fail "Should require --tg-chat-id argument"
fi

# Test 3: Unknown option rejected
output=$(lol serve --unknown 2>&1) || true
if ! echo "$output" | grep -q "Error: Unknown option"; then
  test_fail "Should reject unknown options"
fi

# Test 4: Completion outputs serve-flags
output=$(lol --complete serve-flags 2>/dev/null)
echo "$output" | grep -q "^--tg-token$" || test_fail "Missing flag: --tg-token"
echo "$output" | grep -q "^--tg-chat-id$" || test_fail "Missing flag: --tg-chat-id"
echo "$output" | grep -q "^--period$" || test_fail "Missing flag: --period"

# Test 5: serve appears in command completion
output=$(lol --complete commands 2>/dev/null)
echo "$output" | grep -q "^serve$" || test_fail "Missing command: serve"

test_pass "lol serve validates required arguments correctly"
