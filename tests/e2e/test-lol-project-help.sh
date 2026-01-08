#!/usr/bin/env bash
# Test: lol --help shows project subcommand usage information

source "$(dirname "$0")/../common.sh"

test_info "lol --help shows project subcommand usage information"

# Source the lol CLI library
source "$PROJECT_ROOT/src/cli/lol.sh"

# Capture help output
help_output=$(lol --help 2>&1)

# Test case 1: output includes lol project --create
if echo "$help_output" | grep -q "lol project --create"; then
    test_pass "Help text includes 'lol project --create'"
else
    test_fail "Help text missing 'lol project --create'"
fi

# Test case 2: output includes lol project --associate
if echo "$help_output" | grep -q "lol project --associate"; then
    test_pass "Help text includes 'lol project --associate'"
else
    test_fail "Help text missing 'lol project --associate'"
fi

# Test case 3: output includes lol project --automation
if echo "$help_output" | grep -q "lol project --automation"; then
    test_pass "Help text includes 'lol project --automation'"
else
    test_fail "Help text missing 'lol project --automation'"
fi
