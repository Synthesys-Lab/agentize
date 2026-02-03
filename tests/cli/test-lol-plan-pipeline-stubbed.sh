#!/usr/bin/env bash
# Test: Pipeline flow with stubbed acw
# Tests YAML-based backend overrides plus default (quiet) and --verbose modes via lol plan

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"
PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "Pipeline generates all stage artifacts with stubbed acw"

export AGENTIZE_HOME="$PROJECT_ROOT"
export PYTHONPATH="$PROJECT_ROOT/python"
source "$PLANNER_CLI"
source "$LOL_CLI"

# Create temp directory for test artifacts
TMP_DIR=$(make_temp_dir "test-lol-plan-pipeline-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create YAML config with planner backend override
cat > "$TMP_DIR/.agentize.local.yaml" <<'YAMLEOF'
planner:
  understander: cursor:gpt-5.2-codex
YAMLEOF

# Create a call log to track invocations
CALL_LOG="$TMP_DIR/acw-calls.log"
touch "$CALL_LOG"

# Create stub acw loader for the Python backend
STUB_ACW="$TMP_DIR/acw-stub.sh"
cat > "$STUB_ACW" <<'STUBEOF'
#!/usr/bin/env bash
acw() {
    local provider="$1"
    local model="$2"
    local input_file="$3"
    local output_file="$4"

    if [ "$provider" = "--complete" ] && [ "$model" = "providers" ]; then
        cat <<'EOF'
claude
codex
opencode
cursor
EOF
        return 0
    fi

    echo "acw $provider $model $input_file $output_file" >> "${PLANNER_ACW_CALL_LOG:?}"

    if echo "$output_file" | grep -q "understander"; then
        echo "# Context Summary: Test Feature" > "$output_file"
        echo "Stub understander output" >> "$output_file"
    elif echo "$output_file" | grep -q "bold"; then
        echo "# Bold Proposal: Test Feature" > "$output_file"
        echo "Stub bold proposer output" >> "$output_file"
    elif echo "$output_file" | grep -q "critique"; then
        echo "# Proposal Critique: Test Feature" > "$output_file"
        echo "Stub critique output" >> "$output_file"
    elif echo "$output_file" | grep -q "reducer"; then
        echo "# Simplified Proposal: Test Feature" > "$output_file"
        echo "Stub reducer output" >> "$output_file"
    elif echo "$output_file" | grep -q "consensus"; then
        echo "# Consensus Plan: Test Feature" > "$output_file"
        echo "Stub consensus output" >> "$output_file"
    else
        echo "# Unknown Stage Output" > "$output_file"
        echo "Stub output for unknown stage" >> "$output_file"
    fi
    return 0
}
STUBEOF
chmod +x "$STUB_ACW"

export PLANNER_ACW_CALL_LOG="$CALL_LOG"
export PLANNER_ACW_SCRIPT="$STUB_ACW"

# Disable animation for stable test output
export PLANNER_NO_ANIM=1

# ── Test 1: --dry-run mode (skips issue creation, uses timestamp artifacts) ──
output=$(
    cd "$TMP_DIR" && \
    lol plan --dry-run "Add a test feature for validation" 2>&1
) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan --dry-run exited with non-zero status"
}

# Verify acw was called (at least for understander and bold stages)
CALL_COUNT=$(wc -l < "$CALL_LOG" | tr -d ' ')
if [ "$CALL_COUNT" -lt 2 ]; then
    echo "Call log contents:" >&2
    cat "$CALL_LOG" >&2
    test_fail "Expected at least 2 acw calls, got $CALL_COUNT"
fi

# Verify backend override applied to understander stage
grep -q "acw cursor gpt-5.2-codex" "$CALL_LOG" || {
    echo "Call log contents:" >&2
    cat "$CALL_LOG" >&2
    test_fail "Expected understander stage to use cursor:gpt-5.2-codex"
}

# Verify parallel critique and reducer both invoked (should have 5 total acw calls)
if [ "$CALL_COUNT" -lt 5 ]; then
    echo "Call log contents:" >&2
    cat "$CALL_LOG" >&2
    test_fail "Expected 5 acw calls (understander + bold + critique + reducer + consensus), got $CALL_COUNT"
fi

# Verify consensus output was referenced
echo "$output" | grep -qi "consensus" || {
    echo "Pipeline output: $output" >&2
    test_fail "Pipeline output should reference consensus plan"
}

# Verify per-agent timing logs are present (e.g., "agent understander (claude:sonnet) runs 0s")
echo "$output" | grep -qE "agent [a-z-]+ \\([^)]*\\) runs [0-9]+s" || {
    echo "Pipeline output: $output" >&2
    test_fail "Pipeline output should contain per-agent timing logs (e.g., 'agent understander (provider:model) runs Ns')"
}

# Verify .txt stage artifacts were created
LATEST_UNDERSTANDER=$(ls -t "$PROJECT_ROOT/.tmp/"*-understander.txt 2>/dev/null | head -1)
if [ -z "$LATEST_UNDERSTANDER" ]; then
    test_fail "Expected a understander .txt artifact"
fi
PREFIX="${LATEST_UNDERSTANDER%-understander.txt}"
for stage in bold critique reducer; do
    if [ ! -s "${PREFIX}-${stage}.txt" ]; then
        test_fail "Expected ${PREFIX}-${stage}.txt artifact"
    fi
done

# ── Test 2: --verbose mode outputs detailed stage info ──
> "$CALL_LOG"

output_verbose=$(
    cd "$TMP_DIR" && \
    lol plan --dry-run --verbose "Add verbose test feature" 2>&1
) || {
    echo "Pipeline output: $output_verbose" >&2
    test_fail "lol plan --dry-run --verbose exited with non-zero status"
}

# Verbose output should include stage progress details
echo "$output_verbose" | grep -q "Stage" || {
    echo "Pipeline output: $output_verbose" >&2
    test_fail "Verbose output should include stage progress"
}

test_pass "Pipeline generates all stage artifacts with stubbed acw"
