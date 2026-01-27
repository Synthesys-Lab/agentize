#!/usr/bin/env bash
# Test: planner default issue creation and --dry-run skip
# Default behavior creates an issue; --dry-run skips issue creation

source "$(dirname "$0")/../common.sh"

PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "planner default creates issue, --dry-run skips issue creation"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$PLANNER_CLI"

# Create temp directory for test artifacts
TMP_DIR=$(make_temp_dir "test-planner-issue-mode-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# ── gh stub setup ──
GH_CALL_LOG="$TMP_DIR/gh-calls.log"
touch "$GH_CALL_LOG"

# Create gh stub that logs calls and returns a deterministic issue URL
gh() {
    echo "gh $*" >> "$GH_CALL_LOG"

    if [ "$1" = "issue" ] && [ "$2" = "create" ]; then
        # Return issue URL on stdout
        echo "https://github.com/test/repo/issues/42"
        return 0
    elif [ "$1" = "issue" ] && [ "$2" = "view" ]; then
        # Return issue number for --json number query
        if echo "$*" | grep -q "json.*number"; then
            echo '{"number":42}'
            return 0
        fi
        return 0
    elif [ "$1" = "issue" ] && [ "$2" = "edit" ]; then
        return 0
    fi
    return 0
}
export -f gh 2>/dev/null || true

# ── acw stub setup ──
ACW_CALL_LOG="$TMP_DIR/acw-calls.log"
touch "$ACW_CALL_LOG"

acw() {
    local cli_name="$1"
    local model_name="$2"
    local input_file="$3"
    local output_file="$4"

    echo "acw $cli_name $model_name $input_file $output_file" >> "$ACW_CALL_LOG"

    if grep -q "understander\|context-gathering\|Context Summary" "$input_file" 2>/dev/null; then
        echo "# Context Summary: Test Feature" > "$output_file"
    elif grep -q "bold\|innovative\|Bold Proposal" "$input_file" 2>/dev/null; then
        echo "# Bold Proposal: Test Feature" > "$output_file"
    elif grep -q "critique\|Critical\|feasibility" "$input_file" 2>/dev/null; then
        echo "# Proposal Critique: Test Feature" > "$output_file"
    elif grep -q "simplif\|reducer\|less is more" "$input_file" 2>/dev/null; then
        echo "# Simplified Proposal: Test Feature" > "$output_file"
    else
        echo "# Unknown Stage Output" > "$output_file"
    fi
    return 0
}
export -f acw 2>/dev/null || true

# ── Stub consensus script ──
STUB_CONSENSUS_DIR="$TMP_DIR/consensus-stub"
mkdir -p "$STUB_CONSENSUS_DIR"
STUB_CONSENSUS="$STUB_CONSENSUS_DIR/external-consensus.sh"
cat > "$STUB_CONSENSUS" <<'STUBEOF'
#!/usr/bin/env bash
# Derive consensus path from input filenames (issue-{N} or timestamp prefix)
INPUT_BASE=$(basename "$1")
PREFIX="${INPUT_BASE%-*}"
CONSENSUS_FILE=".tmp/${PREFIX}-consensus.md"
mkdir -p .tmp
# Include preamble before the plan header (real consensus files have this)
echo "Using external-consensus skill to synthesize a balanced plan." > "$CONSENSUS_FILE"
echo "" >> "$CONSENSUS_FILE"
echo "# Implementation Plan: Improved Test Feature" >> "$CONSENSUS_FILE"
echo "" >> "$CONSENSUS_FILE"
echo "Stub consensus output" >> "$CONSENSUS_FILE"
echo "$CONSENSUS_FILE"
exit 0
STUBEOF
chmod +x "$STUB_CONSENSUS"
export _PLANNER_CONSENSUS_SCRIPT="$STUB_CONSENSUS"

# ── Test 1: Default behavior creates issue (no --dry-run) ──
output=$(planner plan "Add a test feature for validation" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "planner plan (default issue mode) exited with non-zero status"
}

# Verify issue-based artifact naming was used (issue-42 prefix)
echo "$output" | grep -q "issue-42" || {
    echo "Output: $output" >&2
    test_fail "Expected issue-42 artifact prefix in output"
}

# Verify gh issue create was called with placeholder title format
grep -q "gh issue create" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh issue create to be called"
}

# Verify placeholder title uses "[plan] placeholder:" format
grep -q '\[plan\] placeholder:' "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected placeholder title with '[plan] placeholder:' prefix"
}

# Verify gh issue edit --add-label was called for publishing
grep -q "add-label.*agentize:plan" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh issue edit --add-label agentize:plan to be called"
}

# Verify final title was extracted from consensus header (not the raw feature description)
grep -q '\[plan\] Improved Test Feature' "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected final title extracted from consensus 'Implementation Plan:' header"
}

# ── Test 2: --dry-run skips issue creation ──
# Reset logs
> "$GH_CALL_LOG"
> "$ACW_CALL_LOG"

output=$(planner plan --dry-run "Add another test feature" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "planner plan --dry-run exited with non-zero status"
}

# Verify NO gh issue create was called
if grep -q "gh issue create" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--dry-run should NOT call gh issue create"
fi

# Verify pipeline still completed (consensus referenced)
echo "$output" | grep -q "consensus\|Consensus" || {
    echo "Output: $output" >&2
    test_fail "Pipeline should still complete with --dry-run"
}

# ── Test 3: Fallback when gh fails (default mode) ──
# Reset logs
> "$GH_CALL_LOG"
> "$ACW_CALL_LOG"

# Override gh to fail
gh() {
    echo "gh $*" >> "$GH_CALL_LOG"
    return 1
}
export -f gh 2>/dev/null || true

output=$(planner plan "Add fallback test feature" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "planner plan should not fail when gh fails (fallback to timestamp)"
}

# Verify fallback warning was emitted
echo "$output" | grep -qi "warn\|fallback\|falling back" || {
    echo "Output: $output" >&2
    test_fail "Expected warning about gh failure and timestamp fallback"
}

# Verify pipeline still completed (consensus referenced)
echo "$output" | grep -q "consensus\|Consensus" || {
    echo "Output: $output" >&2
    test_fail "Pipeline should still complete with timestamp fallback"
}

test_pass "planner default creates issue, --dry-run skips issue creation"
