#!/usr/bin/env bash
# Test: lol --complete commands outputs documented subcommands

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "lol --complete commands outputs documented subcommands"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Get output from lol --complete commands
output=$(lol --complete commands 2>/dev/null)

# Verify documented commands are present
# Check each command individually (shell-neutral approach)
echo "$output" | grep -q "^init$" || test_fail "Missing command: init"
echo "$output" | grep -q "^update$" || test_fail "Missing command: update"
echo "$output" | grep -q "^upgrade$" || test_fail "Missing command: upgrade"
echo "$output" | grep -q "^project$" || test_fail "Missing command: project"

# Verify output is newline-delimited (no spaces, commas, etc.)
if echo "$output" | grep -q " "; then
  test_fail "Output should be newline-delimited, not space-separated"
fi

test_pass "lol --complete commands outputs correct subcommands"
