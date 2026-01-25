#!/usr/bin/env bash
# Test: lol serve handles CLI arguments correctly (YAML-only for TG credentials)

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol serve handles CLI arguments correctly"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Test 1: Server starts without TG args (YAML-only for credentials)
# (Server will fail later at bare repo check, which is expected)
output=$(lol serve 2>&1) || true
# Should NOT have TG-related CLI errors
if echo "$output" | grep -q "Error: --tg-token"; then
  test_fail "Should not mention --tg-token (removed from CLI)"
fi

# Test 2: Unknown option rejected
output=$(lol serve --unknown 2>&1) || true
if ! echo "$output" | grep -q "Error: Unknown option"; then
  test_fail "Should reject unknown options"
fi

# Test 3: Completion outputs serve-flags (only --period and --num-workers)
output=$(lol --complete serve-flags 2>/dev/null)
# TG flags should NOT be in completion anymore
if echo "$output" | grep -q "^--tg-token$"; then
  test_fail "Should NOT have --tg-token flag (moved to YAML-only)"
fi
if echo "$output" | grep -q "^--tg-chat-id$"; then
  test_fail "Should NOT have --tg-chat-id flag (moved to YAML-only)"
fi
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

# Test 6: --period is accepted
output=$(lol serve --period=5m 2>&1) || true
if echo "$output" | grep -q "Error: Unknown option"; then
  test_fail "Should accept --period option"
fi

test_pass "lol serve handles CLI arguments correctly"
