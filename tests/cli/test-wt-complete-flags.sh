#!/usr/bin/env bash
# Test: wt --complete flag topics output documented flags

source "$(dirname "$0")/../common.sh"

WT_CLI="$PROJECT_ROOT/scripts/wt-cli.sh"

test_info "wt --complete flag topics output documented flags"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$WT_CLI"

# Test spawn-flags
spawn_output=$(wt --complete spawn-flags 2>/dev/null)

if ! echo "$spawn_output" | grep -q "^--yolo$"; then
  test_fail "spawn-flags missing: --yolo"
fi

if ! echo "$spawn_output" | grep -q "^--no-agent$"; then
  test_fail "spawn-flags missing: --no-agent"
fi

# Test remove-flags
remove_output=$(wt --complete remove-flags 2>/dev/null)

if ! echo "$remove_output" | grep -q "^--delete-branch$"; then
  test_fail "remove-flags missing: --delete-branch"
fi

if ! echo "$remove_output" | grep -q "^-D$"; then
  test_fail "remove-flags missing: -D (legacy alias)"
fi

if ! echo "$remove_output" | grep -q "^--force$"; then
  test_fail "remove-flags missing: --force (legacy alias)"
fi

# Verify output is newline-delimited
if echo "$spawn_output" | grep -q " "; then
  test_fail "spawn-flags output should be newline-delimited"
fi

if echo "$remove_output" | grep -q " "; then
  test_fail "remove-flags output should be newline-delimited"
fi

# Test unknown topic returns empty
unknown_output=$(wt --complete unknown-topic 2>/dev/null)
if [ -n "$unknown_output" ]; then
  test_fail "Unknown topic should return empty output"
fi

test_pass "wt --complete flag topics output correct flags"
