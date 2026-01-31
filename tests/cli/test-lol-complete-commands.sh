#!/usr/bin/env bash
# Test: lol --complete commands outputs documented subcommands

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol --complete commands outputs documented subcommands"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Get output from lol --complete commands
output=$(lol --complete commands 2>/dev/null)

# Verify documented commands are present
# Check each command individually (shell-neutral approach)
echo "$output" | grep -q "^upgrade$" || test_fail "Missing command: upgrade"
echo "$output" | grep -q "^version$" || test_fail "Missing command: version"
echo "$output" | grep -q "^project$" || test_fail "Missing command: project"
echo "$output" | grep -q "^usage$" || test_fail "Missing command: usage"
echo "$output" | grep -q "^claude-clean$" || test_fail "Missing command: claude-clean"
echo "$output" | grep -q "^plan$" || test_fail "Missing command: plan"
echo "$output" | grep -q "^impl$" || test_fail "Missing command: impl"

# Verify apply command is NOT in the commands list (it has been removed)
if echo "$output" | grep -q "^apply$"; then
  test_fail "apply command should have been removed"
fi

# Verify output is newline-delimited (no spaces, commas, etc.)
if echo "$output" | grep -q " "; then
  test_fail "Output should be newline-delimited, not space-separated"
fi

test_pass "lol --complete commands outputs correct subcommands"
