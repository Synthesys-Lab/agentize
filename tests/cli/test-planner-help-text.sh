#!/usr/bin/env bash
# Test: planner --help output contains usage line and plan subcommand

source "$(dirname "$0")/../common.sh"

PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "planner --help output contains usage and plan subcommand"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$PLANNER_CLI"

# Get help text
output=$(planner --help 2>&1 || true)

# Verify usage line is present
echo "$output" | grep -q "Usage" || test_fail "Help text missing 'Usage' line"

# Verify plan subcommand is documented
echo "$output" | grep -q "plan" || test_fail "Help text missing 'plan' subcommand"

# Verify feature-description is mentioned
echo "$output" | grep -q "feature" || test_fail "Help text missing feature description reference"

# Verify --issue flag is documented
echo "$output" | grep -q "\-\-issue" || test_fail "Help text missing '--issue' flag"

# Verify --issue appears in usage line
echo "$output" | grep -q "\[--issue\]" || test_fail "Help text missing '--issue' in usage line"

test_pass "planner --help output contains usage and plan subcommand"
