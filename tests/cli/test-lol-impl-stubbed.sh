#!/usr/bin/env bash
# Test: lol impl workflow with stubbed wt, acw, and gh
# Tests worktree path resolution, backend parsing, iteration limits, and completion marker detection

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol impl workflow with stubbed dependencies"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Create temp directory for test artifacts
TMP_DIR=$(make_temp_dir "test-lol-impl-$$")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create stub worktree path
STUB_WORKTREE="$TMP_DIR/trees/issue-123"
mkdir -p "$STUB_WORKTREE/.tmp"

# Create call logs to track invocations
WT_CALL_LOG="$TMP_DIR/wt-calls.log"
ACW_CALL_LOG="$TMP_DIR/acw-calls.log"
GH_CALL_LOG="$TMP_DIR/gh-calls.log"
touch "$WT_CALL_LOG" "$ACW_CALL_LOG" "$GH_CALL_LOG"

# Stub wt function
wt() {
    echo "wt $*" >> "$WT_CALL_LOG"
    case "$1" in
        pathto)
            echo "$STUB_WORKTREE"
            return 0
            ;;
        spawn)
            # Simulate worktree spawn (with --no-agent it just creates worktree)
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}
export -f wt 2>/dev/null || true

# Track iteration count for acw
ITERATION_COUNT=0
export ITERATION_COUNT

# Stub acw function
acw() {
    local cli_name="$1"
    local model_name="$2"
    local input_file="$3"
    local output_file="$4"
    shift 4

    echo "acw $cli_name $model_name $input_file $output_file $*" >> "$ACW_CALL_LOG"

    # Increment iteration count
    ITERATION_COUNT=$((ITERATION_COUNT + 1))
    export ITERATION_COUNT

    # Write stub output
    echo "Stub response for iteration $ITERATION_COUNT" > "$output_file"
    return 0
}
export -f acw 2>/dev/null || true

# Stub gh function
gh() {
    echo "gh $*" >> "$GH_CALL_LOG"
    case "$1" in
        pr)
            if [ "$2" = "create" ]; then
                echo "https://github.com/test/repo/pull/1"
            fi
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}
export -f gh 2>/dev/null || true

# ── Test 1: Invalid backend format (missing colon) ──
ITERATION_COUNT=0
output=$(lol impl 123 --backend "invalid_backend" 2>&1) && {
    test_fail "lol impl should fail with invalid backend format"
}

echo "$output" | grep -qi "backend\|provider:model" || {
    echo "Output: $output" >&2
    test_fail "Error message should mention backend format"
}

# ── Test 2: Completion marker detection ──
ITERATION_COUNT=0
> "$ACW_CALL_LOG"

# Stub acw that creates completion marker on second iteration
acw() {
    local cli_name="$1"
    local model_name="$2"
    local input_file="$3"
    local output_file="$4"
    shift 4

    echo "acw $cli_name $model_name $input_file $output_file $*" >> "$ACW_CALL_LOG"

    ITERATION_COUNT=$((ITERATION_COUNT + 1))
    export ITERATION_COUNT

    # On second iteration, create completion marker
    if [ "$ITERATION_COUNT" -eq 2 ]; then
        mkdir -p "$STUB_WORKTREE/.tmp"
        echo "PR: Fix issue 123" > "$STUB_WORKTREE/.tmp/report.txt"
        echo "" >> "$STUB_WORKTREE/.tmp/report.txt"
        echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/report.txt"
    fi

    echo "Stub response for iteration $ITERATION_COUNT" > "$output_file"
    return 0
}
export -f acw 2>/dev/null || true

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed when completion marker appears"
}

# Verify it stopped after finding completion marker
CALL_COUNT=$(wc -l < "$ACW_CALL_LOG" | tr -d ' ')
if [ "$CALL_COUNT" -gt 3 ]; then
    echo "Call count: $CALL_COUNT" >&2
    cat "$ACW_CALL_LOG" >&2
    test_fail "Expected loop to stop after completion marker (got $CALL_COUNT calls)"
fi

# Verify gh pr create was called
if ! grep -q "gh pr create" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh pr create to be called"
fi

# ── Test 3: Max iterations limit ──
ITERATION_COUNT=0
> "$ACW_CALL_LOG"
rm -f "$STUB_WORKTREE/.tmp/report.txt"

# Stub acw that never creates completion marker
acw() {
    local cli_name="$1"
    local model_name="$2"
    local input_file="$3"
    local output_file="$4"

    echo "acw $cli_name $model_name $input_file $output_file" >> "$ACW_CALL_LOG"

    ITERATION_COUNT=$((ITERATION_COUNT + 1))
    export ITERATION_COUNT

    echo "Stub response for iteration $ITERATION_COUNT" > "$output_file"
    return 0
}
export -f acw 2>/dev/null || true

output=$(lol impl 123 --backend codex:gpt-5.2-codex --max-iterations 3 2>&1) && {
    # Should fail because max iterations reached without completion
    test_fail "lol impl should fail when max iterations reached without completion"
}

# Verify it stopped at max iterations
CALL_COUNT=$(wc -l < "$ACW_CALL_LOG" | tr -d ' ')
if [ "$CALL_COUNT" -ne 3 ]; then
    echo "Call count: $CALL_COUNT" >&2
    cat "$ACW_CALL_LOG" >&2
    test_fail "Expected exactly 3 acw calls for --max-iterations 3 (got $CALL_COUNT)"
fi

# Verify error message mentions max iterations
echo "$output" | grep -qi "max.*iteration\|iteration.*limit" || {
    echo "Output: $output" >&2
    test_fail "Error message should mention max iterations limit"
}

# ── Test 4: Backend parsing and provider/model split ──
ITERATION_COUNT=0
> "$ACW_CALL_LOG"

# Create completion marker immediately
mkdir -p "$STUB_WORKTREE/.tmp"
echo "PR: Quick fix" > "$STUB_WORKTREE/.tmp/report.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/report.txt"

acw() {
    echo "acw $1 $2 $3 $4" >> "$ACW_CALL_LOG"
    echo "Stub response" > "$4"
    return 0
}
export -f acw 2>/dev/null || true

output=$(lol impl 123 --backend cursor:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with valid backend"
}

# Verify acw was called with correct provider and model
grep -q "acw cursor gpt-5.2-codex" "$ACW_CALL_LOG" || {
    echo "ACW call log:" >&2
    cat "$ACW_CALL_LOG" >&2
    test_fail "Expected acw to be called with provider=cursor model=gpt-5.2-codex"
}

# ── Test 5: Yolo flag passthrough ──
ITERATION_COUNT=0
> "$ACW_CALL_LOG"

# Redefine acw stub to capture all arguments including flags
acw() {
    echo "acw $*" >> "$ACW_CALL_LOG"
    echo "Stub response" > "$4"
    return 0
}
export -f acw 2>/dev/null || true

output=$(lol impl 123 --backend codex:gpt-5.2-codex --yolo 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with --yolo flag"
}

# Verify yolo flag was passed to acw
grep -q "\-\-yolo" "$ACW_CALL_LOG" || {
    echo "ACW call log:" >&2
    cat "$ACW_CALL_LOG" >&2
    test_fail "Expected --yolo to be passed to acw"
}

test_pass "lol impl workflow with stubbed dependencies"
