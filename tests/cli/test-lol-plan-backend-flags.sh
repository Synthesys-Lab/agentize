#!/usr/bin/env bash
# Test: lol plan backend flags require provider:model format

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"
PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "lol plan rejects invalid backend flag format"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$PLANNER_CLI"
source "$LOL_CLI"

output=$(lol plan --dry-run --understander cursor "Test backend validation" 2>&1) && {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan should fail when backend flag is missing provider:model"
}

echo "$output" | grep -qi "provider:model" || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan should mention provider:model format on error"
}

test_pass "lol plan rejects invalid backend flag format"
