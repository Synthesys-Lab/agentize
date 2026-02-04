#!/usr/bin/env bash
# Test: lol plan default issue creation and --dry-run skip
# Default behavior creates an issue; --dry-run skips issue creation

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"
PLANNER_CLI="$PROJECT_ROOT/src/cli/planner.sh"

test_info "lol plan default creates issue, --dry-run skips issue creation"

export AGENTIZE_HOME="$PROJECT_ROOT"
export PYTHONPATH="$PROJECT_ROOT/python"
source "$PLANNER_CLI"
source "$LOL_CLI"

# Create temp directory for test artifacts
TMP_DIR=$(make_temp_dir "test-lol-plan-issue-mode-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# ── gh stub setup ──
GH_CALL_LOG="$TMP_DIR/gh-calls.log"
touch "$GH_CALL_LOG"
STUB_GH="$TMP_DIR/gh"
cat > "$STUB_GH" <<'STUBEOF'
#!/usr/bin/env bash
set -e

LOG_FILE="${GH_CALL_LOG:?}"

case "$1" in
    auth)
        echo "gh $*" >> "$LOG_FILE"
        exit 0
        ;;
    issue)
        shift
        case "$1" in
            create)
                echo "gh issue create $*" >> "$LOG_FILE"
                if [ "${GH_STUB_MODE:-ok}" = "fail" ]; then
                    exit 1
                fi
                echo "https://github.com/test/repo/issues/42"
                exit 0
                ;;
            view)
                echo "gh issue view $*" >> "$LOG_FILE"
                issue_no="$2"
                shift 2
                if echo "$*" | grep -q ".body"; then
                    echo "# Implementation Plan: Refinement Seed"
                    echo ""
                    echo "Refine this plan."
                    exit 0
                fi
                if echo "$*" | grep -q ".url"; then
                    echo "https://github.com/test/repo/issues/${issue_no}"
                    exit 0
                fi
                echo "{}"
                exit 0
                ;;
            edit)
                echo "gh issue edit $*" >> "$LOG_FILE"
                exit 0
                ;;
        esac
        ;;
    *)
        echo "gh $*" >> "$LOG_FILE"
        exit 0
        ;;
esac
STUBEOF
chmod +x "$STUB_GH"
export GH_CALL_LOG="$GH_CALL_LOG"
export PATH="$TMP_DIR:$PATH"

# ── acw stub setup ──
ACW_CALL_LOG="$TMP_DIR/acw-calls.log"
touch "$ACW_CALL_LOG"
STUB_ACW="$TMP_DIR/acw-stub.sh"
cat > "$STUB_ACW" <<'STUBEOF'
#!/usr/bin/env bash
acw() {
    local cli_name="$1"
    local model_name="$2"
    local input_file="$3"
    local output_file="$4"

    if [ "$cli_name" = "--complete" ] && [ "$model_name" = "providers" ]; then
        cat <<'EOF'
claude
codex
opencode
cursor
EOF
        return 0
    fi

    echo "acw $cli_name $model_name $input_file $output_file" >> "${PLANNER_ACW_CALL_LOG:?}"

    if echo "$output_file" | grep -q "understander"; then
        echo "# Context Summary: Test Feature" > "$output_file"
    elif echo "$output_file" | grep -q "bold"; then
        echo "# Bold Proposal: Test Feature" > "$output_file"
    elif echo "$output_file" | grep -q "critique"; then
        echo "# Proposal Critique: Test Feature" > "$output_file"
    elif echo "$output_file" | grep -q "reducer"; then
        echo "# Simplified Proposal: Test Feature" > "$output_file"
    elif echo "$output_file" | grep -q "consensus"; then
        echo "Using external-consensus prompt to synthesize a balanced plan." > "$output_file"
        echo "" >> "$output_file"
        echo "# Implementation Plan: Improved Test Feature" >> "$output_file"
        echo "" >> "$output_file"
        echo "Stub consensus output" >> "$output_file"
    else
        echo "# Unknown Stage Output" > "$output_file"
    fi
    return 0
}
STUBEOF
chmod +x "$STUB_ACW"
export PLANNER_ACW_CALL_LOG="$ACW_CALL_LOG"
export PLANNER_ACW_SCRIPT="$STUB_ACW"

export PLANNER_NO_ANIM=1

# ── Test 1: Default behavior creates issue (no --dry-run) ──
FEATURE_DESC="Add a test feature for validation with enough length to trim"
output=$(lol plan "$FEATURE_DESC" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan (default issue mode) exited with non-zero status"
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

EXPECTED_SHORT="${FEATURE_DESC:0:50}..."
grep -q "\[plan\] placeholder: ${EXPECTED_SHORT}" "$GH_CALL_LOG" || {
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
grep -q '\[plan\] \[#42\] Improved Test Feature' "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected final title extracted from consensus 'Implementation Plan:' header with issue prefix"
}

# ── Test 2: --dry-run skips issue creation ──
# Reset logs
> "$GH_CALL_LOG"
> "$ACW_CALL_LOG"

output=$(lol plan --dry-run "Add another test feature" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan --dry-run exited with non-zero status"
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

# ── Test 3: --refine uses issue-refine prefix and publishes ──
# Reset logs
> "$GH_CALL_LOG"
> "$ACW_CALL_LOG"

output=$(lol plan --refine 42 "Tighten scope" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan --refine exited with non-zero status"
}

echo "$output" | grep -q "issue-refine-42" || {
    echo "Output: $output" >&2
    test_fail "Expected issue-refine-42 artifact prefix in output"
}

if grep -q "gh issue create" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--refine should NOT create a new issue"
fi

grep -q "gh issue view" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--refine should fetch the existing issue"
}

grep -q "gh issue edit" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--refine should publish updates to the existing issue"
}

# ── Test 4: --dry-run --refine skips publish but keeps issue-refine prefix ──
# Reset logs
> "$GH_CALL_LOG"
> "$ACW_CALL_LOG"

output=$(lol plan --dry-run --refine 42 "Add error cases" 2>&1) || {
    echo "Pipeline output: $output" >&2
    test_fail "lol plan --dry-run --refine exited with non-zero status"
}

echo "$output" | grep -q "issue-refine-42" || {
    echo "Output: $output" >&2
    test_fail "Expected issue-refine-42 artifact prefix in output (dry-run refine)"
}

if grep -q "gh issue create" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--dry-run --refine should NOT create a new issue"
fi

if grep -q "gh issue edit" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--dry-run --refine should NOT publish updates"
fi

grep -q "gh issue view" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "--dry-run --refine should still fetch the issue body"
}

# ── Test 5: gh failure surfaces as error (default mode) ──
# Reset logs
> "$GH_CALL_LOG"
> "$ACW_CALL_LOG"

export GH_STUB_MODE="fail"
if output=$(lol plan "Add fallback test feature" 2>&1); then
    echo "Pipeline output: $output" >&2
    test_fail "lol plan should fail when gh issue creation fails"
fi
export GH_STUB_MODE="ok"

# Verify gh failure bubbled up
echo "$output" | grep -qi "gh issue create" || {
    echo "Output: $output" >&2
    test_fail "Expected gh issue create failure to surface in output"
}

test_pass "lol plan default creates issue, --dry-run skips issue creation"
