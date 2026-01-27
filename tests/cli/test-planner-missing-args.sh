#!/usr/bin/env bash
# Test: planner with no args exits non-zero and prints usage

source "$(dirname "$0")/../common.sh"

PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "planner with no args exits non-zero and prints usage"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$PLANNER_CLI"

# Run planner with no arguments, capture exit code
output=$(planner 2>&1 || true)
planner > /dev/null 2>&1 && test_fail "planner with no args should exit non-zero"

# Verify it prints usage guidance
echo "$output" | grep -qi "usage\|plan" || test_fail "No args output should include usage or plan reference"

# Run planner plan with no feature description
output2=$(planner plan 2>&1 || true)
planner plan > /dev/null 2>&1 && test_fail "planner plan with no description should exit non-zero"

# Verify it mentions the missing description
echo "$output2" | grep -qi "description\|feature\|required" || test_fail "Missing description output should mention what's required"

# Run lol plan with no feature description (lol plan entrypoint)
source "$PROJECT_ROOT/src/cli/lol.sh"
output3=$(lol plan 2>&1 || true)
lol plan > /dev/null 2>&1 && test_fail "lol plan with no description should exit non-zero"

# Verify lol plan error mentions what's required
echo "$output3" | grep -qi "description\|feature\|required" || test_fail "lol plan missing description output should mention what's required"

test_pass "planner with no args exits non-zero and prints usage"
