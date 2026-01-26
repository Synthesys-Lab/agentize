#!/usr/bin/env bash
# Test: lol serve accepts no CLI flags (YAML-only configuration)

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol serve accepts no CLI flags (YAML-only configuration)"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Test 1: Server starts without args (YAML-only for credentials and settings)
# (Server will fail later at bare repo check, which is expected)
output=$(lol serve 2>&1) || true
# Should NOT have TG-related or serve-flag CLI errors
if echo "$output" | grep -q "Error: --tg-token"; then
  test_fail "Should not mention --tg-token (removed from CLI)"
fi

# Test 2: --period is rejected (no longer accepted)
output=$(lol serve --period=5m 2>&1) || true
if ! echo "$output" | grep -q "Error:.*no longer accepts CLI flags\|configure.*\.agentize\.local\.yaml"; then
  test_fail "Should reject --period flag with YAML-only message"
fi

# Test 3: --num-workers is rejected (no longer accepted)
output=$(lol serve --num-workers=3 2>&1) || true
if ! echo "$output" | grep -q "Error:.*no longer accepts CLI flags\|configure.*\.agentize\.local\.yaml"; then
  test_fail "Should reject --num-workers flag with YAML-only message"
fi

# Test 4: Unknown option rejected
output=$(lol serve --unknown 2>&1) || true
if ! echo "$output" | grep -q "Error:"; then
  test_fail "Should reject unknown options"
fi

# Test 5: Completion outputs empty for serve-flags (no CLI flags)
output=$(lol --complete serve-flags 2>/dev/null)
# TG flags should NOT be in completion
if echo "$output" | grep -q "^--tg-token$"; then
  test_fail "Should NOT have --tg-token flag (moved to YAML-only)"
fi
if echo "$output" | grep -q "^--tg-chat-id$"; then
  test_fail "Should NOT have --tg-chat-id flag (moved to YAML-only)"
fi
# Server flags should NOT be in completion anymore
if echo "$output" | grep -q "^--period$"; then
  test_fail "Should NOT have --period flag (moved to YAML-only)"
fi
if echo "$output" | grep -q "^--num-workers$"; then
  test_fail "Should NOT have --num-workers flag (moved to YAML-only)"
fi

# Test 6: serve appears in command completion
output=$(lol --complete commands 2>/dev/null)
echo "$output" | grep -q "^serve$" || test_fail "Missing command: serve"

test_pass "lol serve accepts no CLI flags (YAML-only configuration)"
