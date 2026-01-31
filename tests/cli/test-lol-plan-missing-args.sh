#!/usr/bin/env bash
# Test: lol plan with no args exits non-zero and prints usage

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
PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "lol plan with no args exits non-zero and prints usage"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$PLANNER_CLI"
source "$LOL_CLI"

# Run lol plan with no feature description
output=$(lol plan 2>&1 || true)
lol plan > /dev/null 2>&1 && test_fail "lol plan with no description should exit non-zero"

# Verify lol plan error mentions what's required
echo "$output" | grep -qi "description\|feature\|required" || test_fail "lol plan missing description output should mention what's required"

test_pass "lol plan with no args exits non-zero and prints usage"
