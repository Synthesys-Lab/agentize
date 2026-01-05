#!/usr/bin/env bash
# Test: wt --complete commands outputs documented subcommands

source "$(dirname "$0")/../common.sh"

WT_CLI="$PROJECT_ROOT/scripts/wt-cli.sh"

test_info "wt --complete commands outputs documented subcommands"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$WT_CLI"

# Get output from wt --complete commands
output=$(wt --complete commands 2>/dev/null)

# Verify documented commands are present
expected_commands="init main spawn list remove prune help"
for cmd in $expected_commands; do
  if ! echo "$output" | grep -q "^${cmd}$"; then
    test_fail "Missing command: $cmd"
  fi
done

# Verify legacy 'create' alias is NOT included (not documented)
if echo "$output" | grep -q "^create$"; then
  test_fail "Should not include undocumented 'create' alias"
fi

# Verify output is newline-delimited (no spaces, commas, etc.)
if echo "$output" | grep -q " "; then
  test_fail "Output should be newline-delimited, not space-separated"
fi

test_pass "wt --complete commands outputs correct subcommands"
