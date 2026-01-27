#!/usr/bin/env bash
# Test: planner --help output contains usage line and plan subcommand with new flags

source "$(dirname "$0")/../common.sh"

PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "planner --help output contains usage and plan subcommand with --dry-run and --verbose"

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

# Verify --dry-run flag is documented
echo "$output" | grep -q "\-\-dry-run" || test_fail "Help text missing '--dry-run' flag"

# Verify --verbose flag is documented
echo "$output" | grep -q "\-\-verbose" || test_fail "Help text missing '--verbose' flag"

# Verify --dry-run appears in usage line
echo "$output" | grep -q "\[--dry-run\]" || test_fail "Help text missing '--dry-run' in usage line"

# Verify --verbose appears in usage line
echo "$output" | grep -q "\[--verbose\]" || test_fail "Help text missing '--verbose' in usage line"

test_pass "planner --help output contains usage and plan subcommand with --dry-run and --verbose"
