#!/usr/bin/env bash
# Test: wt --complete commands outputs documented subcommands

source "$(dirname "$0")/../common.sh"

WT_CLI="$PROJECT_ROOT/src/cli/wt.sh"

test_info "wt --complete commands outputs documented subcommands"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$WT_CLI"

# Get output from wt --complete commands
output=$(wt --complete commands 2>/dev/null)

# Verify documented commands are present
# Check each command individually (shell-neutral approach)
echo "$output" | grep -q "^common$" || test_fail "Missing command: common"
echo "$output" | grep -q "^init$" || test_fail "Missing command: init"
echo "$output" | grep -q "^goto$" || test_fail "Missing command: goto"
echo "$output" | grep -q "^spawn$" || test_fail "Missing command: spawn"
echo "$output" | grep -q "^list$" || test_fail "Missing command: list"
echo "$output" | grep -q "^remove$" || test_fail "Missing command: remove"
echo "$output" | grep -q "^prune$" || test_fail "Missing command: prune"
echo "$output" | grep -q "^purge$" || test_fail "Missing command: purge"
echo "$output" | grep -q "^pathto$" || test_fail "Missing command: pathto"
echo "$output" | grep -q "^help$" || test_fail "Missing command: help"

# Verify legacy 'main' alias is NOT included (undocumented, compatibility only)
if echo "$output" | grep -q "^main$"; then
  test_fail "Should not include undocumented 'main' alias"
fi

# Verify legacy 'create' alias is NOT included (not documented)
if echo "$output" | grep -q "^create$"; then
  test_fail "Should not include undocumented 'create' alias"
fi

# Verify legacy 'resolve' is NOT included (replaced by pathto)
if echo "$output" | grep -q "^resolve$"; then
  test_fail "Should not include removed 'resolve' command (use pathto instead)"
fi

# Verify output is newline-delimited (no spaces, commas, etc.)
if echo "$output" | grep -q " "; then
  test_fail "Output should be newline-delimited, not space-separated"
fi

test_pass "wt --complete commands outputs correct subcommands"
