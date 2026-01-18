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
echo "$output" | grep -q "@" || test_fail "Logging format incorrect - missing commit hash separator"
test_info "  ✓ Logging appears on help"

# Test 2: Verify logging includes version tag or commit hash
test_info "Test 2: Verify logging includes version tag or commit hash"
output=$(wt help 2>&1 >/dev/null)
# Extract the part between [agentize] and @
version_part=$(echo "$output" | grep "^\[agentize\]" | sed 's/\[agentize\] //;s/ @.*//')
if [ -z "$version_part" ]; then
  test_fail "Version part is empty"
fi
# Should match either a tag (e.g., v1.0.8) or a commit hash (40 hex chars)
if ! echo "$version_part" | grep -qE '^(v[0-9]+\.[0-9]+\.[0-9]+|[a-f0-9]{7,40})$'; then
  test_fail "Version part format incorrect: $version_part"
fi
test_info "  ✓ Version format correct"

# Test 3: Verify logging format includes full commit hash
test_info "Test 3: Verify logging format includes full commit hash"
output=$(wt help 2>&1 >/dev/null)
# Extract the part after @ (commit hash)
commit_part=$(echo "$output" | grep "^\[agentize\]" | sed 's/.* @ //')
if [ -z "$commit_part" ]; then
  test_fail "Commit hash part is empty"
fi
# Should be at least 7 characters (short hash) or 40 (full hash)
if ! echo "$commit_part" | grep -qE '^[a-f0-9]{7,40}$'; then
  test_fail "Commit hash format incorrect: $commit_part"
fi
test_info "  ✓ Commit hash format correct"

# Test 4: Verify no logging in --complete mode
test_info "Test 4: Verify no logging in --complete mode"
output=$(wt --complete commands 2>&1)
if echo "$output" | grep -q "^\[agentize\]"; then
  test_fail "Logging should be suppressed in --complete mode"
fi
# But completion data should still appear
echo "$output" | grep -q "^clone$" || test_fail "Completion data missing when logging suppressed"
test_info "  ✓ No logging in --complete mode"

# Test 5: Verify logging includes agentize branding
test_info "Test 5: Verify logging includes agentize branding"
output=$(wt help 2>&1 >/dev/null)
echo "$output" | grep -q "^\[agentize\]" || test_fail "Missing agentize branding in logging"
test_info "  ✓ Agentize branding present"

test_pass "wt CLI logging output verified successfully"
