#!/usr/bin/env bash
# Test: acw CLI version logging in help output

source "$(dirname "$0")/../common.sh"

ACW_CLI="$PROJECT_ROOT/src/cli/acw.sh"

test_info "acw CLI version logging in help output"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$ACW_CLI"

# Test 0: Verify logging appears on --help
test_info "Test 0: Verify logging appears on --help"
output=$(acw --help 2>&1)
echo "$output" | grep -q "^\[agentize\]" || test_fail "Logging output missing from help"
test_info "  ✓ Logging appears on --help"

# Test 1: Verify logging format includes branch name and short hash
test_info "Test 1: Verify logging format includes branch name and short hash"
banner=$(echo "$output" | grep "^\[agentize\]" | head -n 1)
if [ -z "$banner" ]; then
  test_fail "Version banner missing"
fi
if ! echo "$banner" | grep -qE '^\[agentize\] [^ ]+ @[a-f0-9]{7}$'; then
  test_fail "Version banner format incorrect: $banner"
fi
test_info "  ✓ Version banner format correct"

test_pass "acw CLI version logging verified successfully"
