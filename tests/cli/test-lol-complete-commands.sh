#!/usr/bin/env bash
# Test: lol --complete commands outputs documented subcommands

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol --complete commands outputs documented subcommands"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Get output from lol --complete commands
output=$(lol --complete commands 2>/dev/null)

# Verify documented commands are present
# Check each command individually (shell-neutral approach)
# Note: init and update are NOT standalone commands, they are --init and --update flags for apply
echo "$output" | grep -q "^apply$" || test_fail "Missing command: apply"
echo "$output" | grep -q "^upgrade$" || test_fail "Missing command: upgrade"
echo "$output" | grep -q "^version$" || test_fail "Missing command: version"
echo "$output" | grep -q "^project$" || test_fail "Missing command: project"
echo "$output" | grep -q "^usage$" || test_fail "Missing command: usage"
echo "$output" | grep -q "^claude-clean$" || test_fail "Missing command: claude-clean"

# Verify init and update are NOT in the commands list (they are flags for apply)
if echo "$output" | grep -q "^init$"; then
  test_fail "init should not be a standalone command (use 'apply --init' instead)"
fi
if echo "$output" | grep -q "^update$"; then
  test_fail "update should not be a standalone command (use 'apply --update' instead)"
fi

# Verify output is newline-delimited (no spaces, commas, etc.)
if echo "$output" | grep -q " "; then
  test_fail "Output should be newline-delimited, not space-separated"
fi

test_pass "lol --complete commands outputs correct subcommands"
