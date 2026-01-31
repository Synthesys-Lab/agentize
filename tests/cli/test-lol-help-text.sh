#!/usr/bin/env bash
# Test: lol usage text includes documented commands

# Shared test helpers
set -e
SCRIPT_PATH="$0"
if [ -n "${BASH_SOURCE[0]-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
if [ "${SCRIPT_PATH%/*}" = "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="."
else
  SCRIPT_DIR="${SCRIPT_PATH%/*}"
fi
source "$SCRIPT_DIR/../common.sh"

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

# Verify usage text includes lol plan command
echo "$output" | grep -q "lol plan" || test_fail "Usage text missing 'lol plan' command"

# Verify usage text includes lol impl command
echo "$output" | grep -q "lol impl" || test_fail "Usage text missing 'lol impl' command"

# Verify lol plan --help includes --refine
plan_help=$(lol plan --help 2>&1)
echo "$plan_help" | grep -q "\-\-refine" || test_fail "lol plan --help missing '--refine' option"

test_pass "lol usage text includes documented commands"
