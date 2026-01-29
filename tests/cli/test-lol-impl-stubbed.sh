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
GIT_CALL_LOG="$TMP_DIR/git-calls.log"
touch "$WT_CALL_LOG" "$ACW_CALL_LOG" "$GH_CALL_LOG" "$GIT_CALL_LOG"

# Stub git function - by default simulates changes exist
GIT_HAS_CHANGES=1
GIT_REMOTES="origin"
GIT_DEFAULT_BRANCH="main"
export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH

git() {
    echo "git $*" >> "$GIT_CALL_LOG"
    case "$1" in
        add)
            return 0
            ;;
        diff)
            if [ "$2" = "--cached" ] && [ "$3" = "--quiet" ]; then
                # Return 1 if changes exist (non-quiet), 0 if no changes
                [ "$GIT_HAS_CHANGES" = "1" ] && return 1 || return 0
            fi
            return 0
            ;;
        commit)
            return 0
            ;;
        remote)
            # List remotes
            echo "$GIT_REMOTES"
            return 0
            ;;
        rev-parse)
            if [ "$2" = "--verify" ]; then
                # Simulate branch exists based on GIT_DEFAULT_BRANCH
                local check_branch="${3#refs/remotes/*/}"
                if [ "$check_branch" = "$GIT_DEFAULT_BRANCH" ]; then
                    return 0
                fi
                return 1
            fi
            return 0
            ;;
        push)
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}
export -f git 2>/dev/null || true

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

# ── Test 6: Issue prefetch success ──
ITERATION_COUNT=0
> "$ACW_CALL_LOG"
> "$GH_CALL_LOG"
rm -f "$STUB_WORKTREE/.tmp/report.txt"
rm -f "$STUB_WORKTREE/.tmp/issue-123.md"
rm -f "$STUB_WORKTREE/.tmp/impl-input.txt"

# Create completion marker immediately
mkdir -p "$STUB_WORKTREE/.tmp"
echo "PR: Prefetch test" > "$STUB_WORKTREE/.tmp/report.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/report.txt"

# Stub gh to provide issue content
gh() {
    echo "gh $*" >> "$GH_CALL_LOG"
    case "$1" in
        issue)
            if [ "$2" = "view" ]; then
                # Return issue content in expected format
                echo "# Test Issue Title"
                echo ""
                echo "Labels: bug, enhancement"
                echo ""
                echo "This is the issue body content."
            fi
            return 0
            ;;
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

acw() {
    echo "acw $*" >> "$ACW_CALL_LOG"
    echo "Stub response" > "$4"
    return 0
}
export -f acw 2>/dev/null || true

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with issue prefetch"
}

# Verify gh issue view was called
grep -q "gh issue view 123" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh issue view to be called for prefetch"
}

# Verify issue file was created
if [ ! -f "$STUB_WORKTREE/.tmp/issue-123.md" ]; then
    test_fail "Expected .tmp/issue-123.md to be created"
fi

# Verify initial prompt references the issue file
if ! grep -q "issue-123.md" "$STUB_WORKTREE/.tmp/impl-input.txt"; then
    echo "impl-input.txt content:" >&2
    cat "$STUB_WORKTREE/.tmp/impl-input.txt" >&2
    test_fail "Expected impl-input.txt to reference issue-123.md"
fi

# ── Test 7: Issue prefetch fallback on failure ──
ITERATION_COUNT=0
> "$ACW_CALL_LOG"
> "$GH_CALL_LOG"
rm -f "$STUB_WORKTREE/.tmp/issue-456.md"
rm -f "$STUB_WORKTREE/.tmp/impl-input.txt"

# Update wt stub to return different worktree for issue 456
wt() {
    echo "wt $*" >> "$WT_CALL_LOG"
    case "$1" in
        pathto)
            echo "$STUB_WORKTREE"
            return 0
            ;;
        spawn)
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}
export -f wt 2>/dev/null || true

# Create completion marker
echo "PR: Fallback test" > "$STUB_WORKTREE/.tmp/report.txt"
echo "Issue 456 resolved" >> "$STUB_WORKTREE/.tmp/report.txt"

# Stub gh to fail for issue view
gh() {
    echo "gh $*" >> "$GH_CALL_LOG"
    case "$1" in
        issue)
            if [ "$2" = "view" ]; then
                # Simulate failure (network error, auth failure, etc.)
                return 1
            fi
            return 0
            ;;
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

output=$(lol impl 456 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed even when prefetch fails"
}

# Verify warning was emitted about prefetch failure
echo "$output" | grep -qi "warning\|failed.*prefetch\|issue.*456" || {
    echo "Output: $output" >&2
    test_fail "Expected warning about prefetch failure"
}

# Verify initial prompt falls back to simple issue number reference
if grep -q "issue-456.md" "$STUB_WORKTREE/.tmp/impl-input.txt" 2>/dev/null; then
    echo "impl-input.txt content:" >&2
    cat "$STUB_WORKTREE/.tmp/impl-input.txt" >&2
    test_fail "Expected impl-input.txt to NOT reference issue file on fallback"
fi

# Verify fallback prompt mentions issue number
if ! grep -q "issue.*456\|#456" "$STUB_WORKTREE/.tmp/impl-input.txt"; then
    echo "impl-input.txt content:" >&2
    cat "$STUB_WORKTREE/.tmp/impl-input.txt" >&2
    test_fail "Expected fallback prompt to mention issue number"
fi

# ── Test 8: Git commit after iteration when changes exist ──
ITERATION_COUNT=0
> "$ACW_CALL_LOG"
> "$GH_CALL_LOG"
> "$GIT_CALL_LOG"
rm -f "$STUB_WORKTREE/.tmp/report.txt"
GIT_HAS_CHANGES=1
GIT_REMOTES="origin"
GIT_DEFAULT_BRANCH="main"
export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH

# Reset wt stub
wt() {
    echo "wt $*" >> "$WT_CALL_LOG"
    case "$1" in
        pathto) echo "$STUB_WORKTREE"; return 0 ;;
        spawn) return 0 ;;
        *) return 0 ;;
    esac
}
export -f wt 2>/dev/null || true

# Stub acw that creates completion marker on second iteration
acw() {
    local output_file="$4"
    echo "acw $*" >> "$ACW_CALL_LOG"
    ITERATION_COUNT=$((ITERATION_COUNT + 1))
    export ITERATION_COUNT
    if [ "$ITERATION_COUNT" -eq 2 ]; then
        mkdir -p "$STUB_WORKTREE/.tmp"
        echo "PR: Git commit test" > "$STUB_WORKTREE/.tmp/report.txt"
        echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/report.txt"
    fi
    echo "Stub response for iteration $ITERATION_COUNT" > "$output_file"
    return 0
}
export -f acw 2>/dev/null || true

# Reset gh stub
gh() {
    echo "gh $*" >> "$GH_CALL_LOG"
    case "$1" in
        pr) [ "$2" = "create" ] && echo "https://github.com/test/repo/pull/1"; return 0 ;;
        *) return 0 ;;
    esac
}
export -f gh 2>/dev/null || true

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with git commit enabled"
}

# Verify git add was called for each iteration
if ! grep -q "git add -A" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git add -A to be called"
fi

# Verify git commit was called (since GIT_HAS_CHANGES=1)
if ! grep -q "git commit" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git commit to be called when changes exist"
fi

# ── Test 9: Skip commit when no changes ──
ITERATION_COUNT=0
> "$ACW_CALL_LOG"
> "$GH_CALL_LOG"
> "$GIT_CALL_LOG"
rm -f "$STUB_WORKTREE/.tmp/report.txt"
GIT_HAS_CHANGES=0  # No changes
export GIT_HAS_CHANGES

# Create completion marker immediately
echo "PR: No changes test" > "$STUB_WORKTREE/.tmp/report.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/report.txt"

acw() {
    echo "acw $*" >> "$ACW_CALL_LOG"
    echo "Stub response" > "$4"
    return 0
}
export -f acw 2>/dev/null || true

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed even with no changes"
}

# Verify git add was called
if ! grep -q "git add -A" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git add -A to be called"
fi

# Verify git commit was NOT called (since GIT_HAS_CHANGES=0)
if grep -q "git commit" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git commit to NOT be called when no changes"
fi

# ── Test 10: Push remote precedence (upstream over origin) ──
ITERATION_COUNT=0
> "$ACW_CALL_LOG"
> "$GH_CALL_LOG"
> "$GIT_CALL_LOG"
GIT_HAS_CHANGES=1
GIT_REMOTES=$'upstream\norigin'  # Both remotes available
GIT_DEFAULT_BRANCH="master"
export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH

# Create completion marker immediately
echo "PR: Remote precedence test" > "$STUB_WORKTREE/.tmp/report.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/report.txt"

acw() {
    echo "acw $*" >> "$ACW_CALL_LOG"
    echo "Stub response" > "$4"
    return 0
}
export -f acw 2>/dev/null || true

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with upstream remote"
}

# Verify git push used upstream (not origin)
if ! grep -q "git push -u upstream" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git push to use upstream remote"
fi

# ── Test 11: Base branch selection (master over main) ──
# The previous test already sets GIT_DEFAULT_BRANCH="master"
# Verify gh pr create used --base master
if ! grep -q "gh pr create.*--base master" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh pr create with --base master"
fi

# ── Test 12: Fallback to origin and main when upstream/master unavailable ──
ITERATION_COUNT=0
> "$ACW_CALL_LOG"
> "$GH_CALL_LOG"
> "$GIT_CALL_LOG"
GIT_HAS_CHANGES=1
GIT_REMOTES="origin"  # Only origin available
GIT_DEFAULT_BRANCH="main"
export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH

# Create completion marker immediately
echo "PR: Fallback remote test" > "$STUB_WORKTREE/.tmp/report.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/report.txt"

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with origin fallback"
}

# Verify git push used origin
if ! grep -q "git push -u origin" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git push to use origin remote"
fi

# Verify gh pr create used --base main
if ! grep -q "gh pr create.*--base main" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh pr create with --base main"
fi

test_pass "lol impl workflow with stubbed dependencies"
