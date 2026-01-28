#!/usr/bin/env bash
# Test: planner backend flags require provider:model format

source "$(dirname "$0")/../common.sh"

PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "planner rejects invalid backend flag format"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$PLANNER_CLI"

output=$(planner plan --dry-run --understander cursor "Test backend validation" 2>&1) && {
    echo "Pipeline output: $output" >&2
    test_fail "planner plan should fail when backend flag is missing provider:model"
}

echo "$output" | grep -qi "provider:model" || {
    echo "Pipeline output: $output" >&2
    test_fail "planner plan should mention provider:model format on error"
}

test_pass "planner rejects invalid backend flag format"
