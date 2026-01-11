#!/usr/bin/env bash
# Test: lol usage text includes documented commands

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol usage text includes documented commands"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Get usage text from lol (no arguments shows usage)
# Note: lol returns exit code 1 when showing help, so we need to handle this
output=$(lol 2>&1 || true)

# Verify usage text includes lol upgrade command
echo "$output" | grep -q "lol upgrade" || test_fail "Usage text missing 'lol upgrade' command"

# Verify usage text includes --version flag
echo "$output" | grep -q "\-\-version" || test_fail "Usage text missing '--version' flag"

# Verify usage text includes claude-clean command
echo "$output" | grep -q "claude-clean" || test_fail "Usage text missing 'claude-clean' command"

# Verify usage text includes lol usage command
echo "$output" | grep -q "lol usage" || test_fail "Usage text missing 'lol usage' command"

test_pass "lol usage text includes documented commands"
