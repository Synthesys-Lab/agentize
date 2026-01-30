#!/usr/bin/env bash
# Test: Pipeline flow with stubbed acw and consensus script
# Tests YAML-based backend overrides plus default (quiet) and --verbose modes via lol plan

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"
PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "Pipeline generates all stage artifacts with stubbed acw and consensus"

export AGENTIZE_HOME="$PROJECT_ROOT"
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

# Create stub acw that writes fake output and logs calls
acw() {
    local cli_name="$1"
    local model_name="$2"
    local input_file="$3"
    local output_file="$4"

    echo "acw $cli_name $model_name $input_file $output_file" >> "$CALL_LOG"

    # Write stub output based on the input content
    if grep -q "understander\|context-gathering\|Context Summary" "$input_file" 2>/dev/null; then
        echo "# Context Summary: Test Feature" > "$output_file"
        echo "Stub understander output" >> "$output_file"
    elif grep -q "bold\|innovative\|Bold Proposal" "$input_file" 2>/dev/null; then
        echo "# Bold Proposal: Test Feature" > "$output_file"
        echo "Stub bold proposer output" >> "$output_file"
    elif grep -q "critique\|Critical\|feasibility" "$input_file" 2>/dev/null; then
        echo "# Proposal Critique: Test Feature" > "$output_file"
        echo "Stub critique output" >> "$output_file"
    elif grep -q "simplif\|reducer\|less is more" "$input_file" 2>/dev/null; then
        echo "# Simplified Proposal: Test Feature" > "$output_file"
        echo "Stub reducer output" >> "$output_file"
    else
        echo "# Unknown Stage Output" > "$output_file"
        echo "Stub output for unknown stage" >> "$output_file"
    fi
    return 0
}
export -f acw 2>/dev/null || true

# Create stub consensus script
STUB_CONSENSUS_DIR="$TMP_DIR/consensus-stub"
mkdir -p "$STUB_CONSENSUS_DIR"
STUB_CONSENSUS="$STUB_CONSENSUS_DIR/external-consensus.sh"
cat > "$STUB_CONSENSUS" <<'STUBEOF'
#!/usr/bin/env bash
# Stub consensus script
CONSENSUS_FILE=".tmp/stub-consensus.md"
mkdir -p .tmp
echo "# Consensus Plan: Test Feature" > "$CONSENSUS_FILE"
echo "Stub consensus output from $1 $2 $3" >> "$CONSENSUS_FILE"
echo "$CONSENSUS_FILE"
exit 0
STUBEOF
chmod +x "$STUB_CONSENSUS"

# Override the consensus script path used by pipeline
export _PLANNER_CONSENSUS_SCRIPT="$STUB_CONSENSUS"

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

# Verify parallel critique and reducer both invoked (should have 4 total acw calls)
if [ "$CALL_COUNT" -lt 4 ]; then
    echo "Call log contents:" >&2
    cat "$CALL_LOG" >&2
    test_fail "Expected 4 acw calls (understander + bold + critique + reducer), got $CALL_COUNT"
fi

# Verify consensus output was referenced
echo "$output" | grep -q "consensus\|Consensus" || {
    echo "Pipeline output: $output" >&2
    test_fail "Pipeline output should reference consensus plan"
}

# Verify per-agent timing logs are present (e.g., "understander agent runs 0s")
echo "$output" | grep -qE "agent runs [0-9]+s" || {
    echo "Pipeline output: $output" >&2
    test_fail "Pipeline output should contain per-agent timing logs (e.g., 'agent runs Ns')"
}

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

test_pass "Pipeline generates all stage artifacts with stubbed acw and consensus"
