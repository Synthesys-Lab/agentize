#!/usr/bin/env bash
# Test: wt CLI logging output at startup

source "$(dirname "$0")/../common.sh"

WT_CLI="$PROJECT_ROOT/src/cli/wt.sh"

test_info "wt CLI logging output at startup"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$WT_CLI"

# Test 0: Verify logging appears on invalid command (which shows help)
test_info "Test 0: Verify logging appears on invalid command"
output=$(wt nonexistent 2>&1 || true)
echo "$output" | grep -q "^\[agentize\]" || test_fail "Logging should appear on invalid command"
test_info "  ✓ Logging appears on invalid command"

# Test 1: Verify logging appears in stderr on help command
test_info "Test 1: Verify logging appears in stderr on help command"
output=$(wt help 2>&1 >/dev/null)
echo "$output" | grep -q "^\[agentize\]" || test_fail "Logging output missing from stderr"
test_info "  ✓ Logging appears on help"

# Test 2: Verify logging format includes branch name and short hash
test_info "Test 2: Verify logging format includes branch name and short hash"
output=$(wt help 2>&1 >/dev/null)
banner=$(echo "$output" | grep "^\[agentize\]" | head -n 1)
if [ -z "$banner" ]; then
  test_fail "Version banner missing"
fi
if ! echo "$banner" | grep -qE '^\[agentize\] [^ ]+ @[a-f0-9]{7}$'; then
  test_fail "Version banner format incorrect: $banner"
fi
test_info "  ✓ Version banner format correct"

# Test 3: Verify no logging in --complete mode
test_info "Test 3: Verify no logging in --complete mode"
output=$(wt --complete commands 2>&1)
if echo "$output" | grep -q "^\[agentize\]"; then
  test_fail "Logging should be suppressed in --complete mode"
fi
# But completion data should still appear
echo "$output" | grep -q "^clone$" || test_fail "Completion data missing when logging suppressed"
test_info "  ✓ No logging in --complete mode"

# Test 4: Verify logging includes agentize branding
test_info "Test 4: Verify logging includes agentize branding"
output=$(wt help 2>&1 >/dev/null)
echo "$output" | grep -q "^\[agentize\]" || test_fail "Missing agentize branding in logging"
test_info "  ✓ Agentize branding present"

test_pass "wt CLI logging output verified successfully"
