#!/usr/bin/env bash
# Test: lol serve handles optional TG arguments correctly

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol serve handles optional TG arguments"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Test 1: Missing TG args no longer produces "required" error
# (Server will fail later at bare repo check, which is expected)
output=$(lol serve 2>&1) || true
if echo "$output" | grep -q "Error: --tg-token is required"; then
  test_fail "Should NOT require --tg-token argument (now optional)"
fi
if echo "$output" | grep -q "Error: --tg-chat-id is required"; then
  test_fail "Should NOT require --tg-chat-id argument (now optional)"
fi

# Test 2: Unknown option rejected
output=$(lol serve --unknown 2>&1) || true
if ! echo "$output" | grep -q "Error: Unknown option"; then
  test_fail "Should reject unknown options"
fi

# Test 3: Completion outputs serve-flags
output=$(lol --complete serve-flags 2>/dev/null)
echo "$output" | grep -q "^--tg-token$" || test_fail "Missing flag: --tg-token"
echo "$output" | grep -q "^--tg-chat-id$" || test_fail "Missing flag: --tg-chat-id"
echo "$output" | grep -q "^--period$" || test_fail "Missing flag: --period"
echo "$output" | grep -q "^--num-workers$" || test_fail "Missing flag: --num-workers"

# Test 4: --num-workers is accepted (not rejected as unknown)
output=$(lol serve --num-workers=3 2>&1) || true
if echo "$output" | grep -q "Error: Unknown option"; then
  test_fail "Should accept --num-workers option"
fi

# Test 5: serve appears in command completion
output=$(lol --complete commands 2>/dev/null)
echo "$output" | grep -q "^serve$" || test_fail "Missing command: serve"

# Test 6: TG args are still accepted when provided
output=$(lol serve --tg-token=xxx --tg-chat-id=yyy 2>&1) || true
if echo "$output" | grep -q "Error: Unknown option"; then
  test_fail "Should accept --tg-token and --tg-chat-id options"
fi

test_pass "lol serve handles optional TG arguments correctly"
