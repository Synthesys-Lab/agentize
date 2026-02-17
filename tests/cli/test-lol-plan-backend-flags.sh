#!/usr/bin/env bash
# Test: lol plan backend flags are handled consistently

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"
PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "lol plan accepts --backend and forwards it to the planner pipeline"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$PLANNER_CLI"
source "$LOL_CLI"

captured_args=""
_planner_run_pipeline() {
    captured_args="$*"
    return 0
}

TMP_DIR="$(make_temp_dir "test-lol-plan-backend-flags")"
output_file="$TMP_DIR/output.txt"

if ! lol plan --dry-run --backend codex:gpt-5.2-codex "Test backend override" >"$output_file" 2>&1; then
    output="$(cat "$output_file")"
    echo "Pipeline output: $output" >&2
    test_fail "lol plan should accept --backend"
fi

echo "$captured_args" | grep -q "codex:gpt-5.2-codex" || {
    echo "Captured args: $captured_args" >&2
    test_fail "lol plan should forward --backend to planner pipeline"
}

test_info "lol plan rejects stage-specific backend flags"

if lol plan --dry-run --understander cursor:gpt-5.2-codex "Test backend validation" >"$output_file" 2>&1; then
    output="$(cat "$output_file")"
    echo "Pipeline output: $output" >&2
    test_fail "lol plan should fail when stage-specific backend flags are provided"
fi

output="$(cat "$output_file")"
echo "$output" | grep -qi "agentize.local.yaml" || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan should point to .agentize.local.yaml for backend configuration"
}

test_pass "lol plan backend flags are handled correctly"
