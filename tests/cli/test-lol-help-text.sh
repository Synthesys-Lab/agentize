#!/usr/bin/env bash
# Test: lol usage text includes lol upgrade

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "lol usage text includes lol upgrade"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Get usage text from lol (no arguments shows usage)
output=$(lol 2>&1)

# Verify usage text includes lol upgrade command
if ! echo "$output" | grep -q "lol upgrade"; then
  test_fail "Usage text missing 'lol upgrade' command"
fi

test_pass "lol usage text includes lol upgrade"
