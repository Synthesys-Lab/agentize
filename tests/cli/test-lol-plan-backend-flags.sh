#!/usr/bin/env bash
# Test: lol plan backend flags are removed (use .agentize.local.yaml)

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"
PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "lol plan rejects backend flags and points to .agentize.local.yaml"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$PLANNER_CLI"
source "$LOL_CLI"

output=$(lol plan --dry-run --understander cursor:gpt-5.2-codex "Test backend validation" 2>&1) && {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan should fail when backend flags are provided"
}

echo "$output" | grep -qi "backend" || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan should mention backend flags on error"
}

echo "$output" | grep -qi "agentize.local.yaml" || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan should point to .agentize.local.yaml for backend configuration"
}

test_pass "lol plan rejects backend flags and points to .agentize.local.yaml"
