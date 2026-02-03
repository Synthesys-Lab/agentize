#!/usr/bin/env bash
# Test: lol impl workflow with stubbed wt, acw, and gh via overrides
# Tests worktree path resolution, backend parsing, iteration limits, and completion marker detection

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol impl workflow with stubbed dependencies"

export AGENTIZE_HOME="$PROJECT_ROOT"
export PYTHONPATH="$PROJECT_ROOT/python"
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
CALL_ORDER_LOG="$TMP_DIR/call-order.log"
touch "$WT_CALL_LOG" "$ACW_CALL_LOG" "$GH_CALL_LOG" "$GIT_CALL_LOG" "$CALL_ORDER_LOG"

# Track iteration count across subprocesses
ITERATION_COUNT_FILE="$TMP_DIR/iter-count.txt"
echo 0 > "$ITERATION_COUNT_FILE"

# Stub git behavior controls
GIT_HAS_CHANGES=1
GIT_REMOTES="origin"
GIT_DEFAULT_BRANCH="main"
GIT_BRANCH_NAME="test-branch"
GIT_FETCH_FAILS=0
GIT_REBASE_FAILS=0
export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH GIT_BRANCH_NAME
export GIT_FETCH_FAILS GIT_REBASE_FAILS

# Shell override script for subprocess invocations
OVERRIDES="$TMP_DIR/shell-overrides.sh"
cat <<'OVERRIDES_EOF' > "$OVERRIDES"
#!/usr/bin/env bash

_next_iter() {
    local count=0
    if [ -f "$ITERATION_COUNT_FILE" ]; then
        count=$(cat "$ITERATION_COUNT_FILE")
    fi
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        count=0
    fi
    count=$((count + 1))
    echo "$count" > "$ITERATION_COUNT_FILE"
    echo "$count"
}

write_commit_report() {
    local iter="$1"
    mkdir -p "$STUB_WORKTREE/.tmp"
    echo "cli: stub commit report $iter" > "$STUB_WORKTREE/.tmp/commit-report-iter-$iter.txt"
}

_write_finalize() {
    local issue_no="$STUB_ISSUE_NO"
    local finalize_file="$STUB_WORKTREE/.tmp/finalize.txt"
    mkdir -p "$STUB_WORKTREE/.tmp"
    if [ -n "$ACW_FINALIZE_CONTENT" ]; then
        printf "%s\n" "$ACW_FINALIZE_CONTENT" > "$finalize_file"
    else
        echo "PR: Stub finalize" > "$finalize_file"
        echo "" >> "$finalize_file"
        echo "Issue ${issue_no} resolved" >> "$finalize_file"
    fi
}

log_git_call() {
    echo "git $*" >> "$GIT_CALL_LOG"
    echo "git $*" >> "$CALL_ORDER_LOG"
}

log_acw_call() {
    echo "acw $*" >> "$ACW_CALL_LOG"
    echo "acw $*" >> "$CALL_ORDER_LOG"
}

wt() {
    echo "wt $*" >> "$WT_CALL_LOG"
    case "$1" in
        pathto)
            if [ "${WT_PATHTO_FAIL:-0}" = "1" ]; then
                return 1
            fi
            echo "$STUB_WORKTREE"
            return 0
            ;;
        spawn)
            if [ "${WT_SPAWN_FAIL:-0}" = "1" ]; then
                return 1
            fi
            return 0
            ;;
        goto)
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

acw() {
    local provider="$1"
    local model="$2"
    local input_file="$3"
    local output_file="$4"
    shift 4

    if [ "$provider" = "--complete" ] && [ "$model" = "providers" ]; then
        cat <<'EOF'
claude
codex
opencode
cursor
EOF
        return 0
    fi

    log_acw_call "$provider" "$model" "$input_file" "$output_file" "$*"

    local iter
    iter=$(_next_iter)

    if [ "${ACW_WRITE_COMMIT_REPORT:-1}" = "1" ]; then
        write_commit_report "$iter"
    fi

    if [ -n "$ACW_COMPLETION_ITER" ] && [ "$iter" -eq "$ACW_COMPLETION_ITER" ]; then
        _write_finalize
    fi

    if [ -n "$ACW_OUTPUT_TEXT" ]; then
        echo "$ACW_OUTPUT_TEXT" > "$output_file"
    else
        echo "Stub response for iteration $iter" > "$output_file"
    fi
    return 0
}

gh() {
    echo "gh $*" >> "$GH_CALL_LOG"
    case "$1" in
        issue)
            if [ "$2" = "view" ]; then
                if [ "${GH_FAIL_ISSUE_VIEW:-0}" = "1" ]; then
                    return 1
                fi
                echo "# Stub Issue Title"
                echo ""
                echo "Labels: test"
                echo ""
                echo "Stub issue body."
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

git() {
    log_git_call "$@"
    case "$1" in
        add)
            return 0
            ;;
        diff)
            if [ "$2" = "--cached" ] && [ "$3" = "--quiet" ]; then
                [ "$GIT_HAS_CHANGES" = "1" ] && return 1 || return 0
            fi
            return 0
            ;;
        commit)
            return 0
            ;;
        remote)
            echo "$GIT_REMOTES"
            return 0
            ;;
        rev-parse)
            if [ "$2" = "--verify" ]; then
                local check_branch="${3#refs/remotes/*/}"
                if [ "$check_branch" = "$GIT_DEFAULT_BRANCH" ]; then
                    return 0
                fi
                return 1
            fi
            return 0
            ;;
        branch)
            if [ "$2" = "--show-current" ]; then
                echo "${GIT_BRANCH_NAME}"
                return 0
            fi
            return 0
            ;;
        push)
            return 0
            ;;
        fetch)
            [ "$GIT_FETCH_FAILS" = "1" ] && return 1
            return 0
            ;;
        rebase)
            [ "$GIT_REBASE_FAILS" = "1" ] && return 1
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}
OVERRIDES_EOF

export AGENTIZE_SHELL_OVERRIDES="$OVERRIDES"
export STUB_WORKTREE WT_CALL_LOG ACW_CALL_LOG GH_CALL_LOG GIT_CALL_LOG CALL_ORDER_LOG
export ITERATION_COUNT_FILE

reset_iteration() {
    echo 0 > "$ITERATION_COUNT_FILE"
}

reset_logs() {
    : > "$WT_CALL_LOG"
    : > "$ACW_CALL_LOG"
    : > "$GH_CALL_LOG"
    : > "$GIT_CALL_LOG"
    : > "$CALL_ORDER_LOG"
}

reset_stub_state() {
    reset_iteration
    reset_logs
    unset ACW_COMPLETION_ITER
    unset ACW_WRITE_COMMIT_REPORT
    unset ACW_FINALIZE_CONTENT
    unset ACW_OUTPUT_TEXT
    unset GH_FAIL_ISSUE_VIEW
    unset WT_PATHTO_FAIL
    unset WT_SPAWN_FAIL
    GIT_HAS_CHANGES=1
    GIT_REMOTES="origin"
    GIT_DEFAULT_BRANCH="main"
    GIT_FETCH_FAILS=0
    GIT_REBASE_FAILS=0
    export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH
    export GIT_FETCH_FAILS GIT_REBASE_FAILS
}

# ── Test 1: Invalid backend format (missing colon) ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO

output=$(lol impl 123 --backend "invalid_backend" 2>&1) && {
    test_fail "lol impl should fail with invalid backend format"
}

echo "$output" | grep -qi "backend\|provider:model" || {
    echo "Output: $output" >&2
    test_fail "Error message should mention backend format"
}

# ── Test 2: Completion marker detection (using finalize.txt) ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
ACW_COMPLETION_ITER=2
export ACW_COMPLETION_ITER

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

# Clean up for next test
rm -f "$STUB_WORKTREE/.tmp/finalize.txt"

# ── Test 3: Max iterations limit ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO

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

# Verify error message mentions max iterations and both file names
echo "$output" | grep -qi "max.*iteration\|iteration.*limit" || {
    echo "Output: $output" >&2
    test_fail "Error message should mention max iterations limit"
}

# Verify error message mentions finalize.txt
echo "$output" | grep -qi "finalize" || {
    echo "Output: $output" >&2
    test_fail "Error message should mention finalize.txt"
}

# ── Test 4: Backend parsing and provider/model split ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO

# Create completion marker immediately
mkdir -p "$STUB_WORKTREE/.tmp"
echo "PR: Quick fix" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

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
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO

# Create completion marker immediately
echo "PR: Yolo test" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

output=$(lol impl 123 --backend codex:gpt-5.2-codex --yolo 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with --yolo flag"
}

# Verify yolo flag was passed to acw
grep -q -- "--yolo" "$ACW_CALL_LOG" || {
    echo "ACW call log:" >&2
    cat "$ACW_CALL_LOG" >&2
    test_fail "Expected --yolo to be passed to acw"
}

# ── Test 6: Issue prefetch success ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
rm -f "$STUB_WORKTREE/.tmp/finalize.txt"
rm -f "$STUB_WORKTREE/.tmp/issue-123.md"
rm -f "$STUB_WORKTREE/.tmp/impl-input-"*

# Create completion marker immediately
mkdir -p "$STUB_WORKTREE/.tmp"
echo "PR: Prefetch test" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

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
if ! grep -q "issue-123.md" "$STUB_WORKTREE/.tmp/impl-input-1.txt"; then
    echo "impl-input-1.txt content:" >&2
    cat "$STUB_WORKTREE/.tmp/impl-input-1.txt" >&2
    test_fail "Expected impl-input-1.txt to reference issue-123.md"
fi

# ── Test 7: Issue prefetch failure stops execution ──
reset_stub_state
STUB_ISSUE_NO=456
export STUB_ISSUE_NO
GH_FAIL_ISSUE_VIEW=1
export GH_FAIL_ISSUE_VIEW
rm -f "$STUB_WORKTREE/.tmp/issue-456.md"
rm -f "$STUB_WORKTREE/.tmp/impl-input-"*

# Create completion marker
echo "PR: Fallback test" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 456 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

output=$(lol impl 456 --backend codex:gpt-5.2-codex 2>&1) && {
    echo "Output: $output" >&2
    test_fail "lol impl should fail when prefetch fails"
}

# Verify error was emitted about prefetch failure
echo "$output" | grep -qi "failed to fetch issue content" || {
    echo "Output: $output" >&2
    test_fail "Expected error about prefetch failure"
}

# Verify no initial prompt file was written
if [ -f "$STUB_WORKTREE/.tmp/impl-input-1.txt" ]; then
    echo "impl-input-1.txt content:" >&2
    cat "$STUB_WORKTREE/.tmp/impl-input-1.txt" >&2
    test_fail "Expected impl-input-1.txt to not be created on prefetch failure"
fi

# ── Test 8: Git commit after iteration when changes exist ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
GIT_HAS_CHANGES=1
GIT_REMOTES="origin"
GIT_DEFAULT_BRANCH="main"
export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH
ACW_COMPLETION_ITER=2
export ACW_COMPLETION_ITER

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
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
GIT_HAS_CHANGES=0  # No changes
export GIT_HAS_CHANGES

# Create completion marker immediately
echo "PR: No changes test" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

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

# ── Test 9b: Per-iteration commit report file ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
find "$STUB_WORKTREE/.tmp" -name 'commit-report-iter-*.txt' -delete 2>/dev/null || true
GIT_HAS_CHANGES=1
export GIT_HAS_CHANGES

# Create completion marker
mkdir -p "$STUB_WORKTREE/.tmp"
echo "PR: Commit report test" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with commit-report file"
}

# Verify git commit used the commit-report file
if ! grep -q "git commit -F .*commit-report-iter-1.txt" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git commit to use commit-report-iter-1.txt"
fi

# Clean up
rm -f "$STUB_WORKTREE/.tmp/finalize.txt"
find "$STUB_WORKTREE/.tmp" -name 'commit-report-iter-*.txt' -delete 2>/dev/null || true

# ── Test 9c: Fail when commit report file missing ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
find "$STUB_WORKTREE/.tmp" -name 'commit-report-iter-*.txt' -delete 2>/dev/null || true
GIT_HAS_CHANGES=1
export GIT_HAS_CHANGES
ACW_WRITE_COMMIT_REPORT=0
export ACW_WRITE_COMMIT_REPORT

# Create completion marker but no commit report file
mkdir -p "$STUB_WORKTREE/.tmp"
echo "PR: Missing report test" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) && {
    echo "Output: $output" >&2
    test_fail "lol impl should fail when commit report is missing"
}

# Verify error message mentions missing commit report
echo "$output" | grep -qi "missing commit report" || {
    echo "Output: $output" >&2
    test_fail "Expected missing commit report error"
}

# Clean up
rm -f "$STUB_WORKTREE/.tmp/finalize.txt"

# ── Test 10: Push remote precedence (upstream over origin) ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
GIT_HAS_CHANGES=1
GIT_REMOTES=$'upstream\norigin'  # Both remotes available
GIT_DEFAULT_BRANCH="master"
export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH

# Create completion marker immediately
echo "PR: Remote precedence test" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

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
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
GIT_HAS_CHANGES=1
GIT_REMOTES="origin"  # Only origin available
GIT_DEFAULT_BRANCH="main"
export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH

# Create completion marker immediately
echo "PR: Fallback remote test" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

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

# ── Test 13: Closes-line deduplication when already present ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
GIT_HAS_CHANGES=1
GIT_REMOTES="origin"
GIT_DEFAULT_BRANCH="main"
export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH

# Create completion marker with closes line already present (lowercase)
mkdir -p "$STUB_WORKTREE/.tmp"
echo "PR: Closes dedup test" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "" >> "$STUB_WORKTREE/.tmp/finalize.txt"
echo "closes #123" >> "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with existing closes line"
}

# Count occurrences of closes line in gh pr create call
CLOSES_COUNT=$(grep -oi "closes #123" "$GH_CALL_LOG" | wc -l | tr -d ' ')
if [ "$CLOSES_COUNT" -ne 1 ]; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected exactly one 'closes #123' in PR body (got $CLOSES_COUNT)"
fi

# ── Test 14: Closes-line append when missing ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
GIT_HAS_CHANGES=1
GIT_REMOTES="origin"
GIT_DEFAULT_BRANCH="main"
export GIT_HAS_CHANGES GIT_REMOTES GIT_DEFAULT_BRANCH

# Create completion marker without closes line
mkdir -p "$STUB_WORKTREE/.tmp"
echo "PR: Closes append test" > "$STUB_WORKTREE/.tmp/finalize.txt"
echo "" >> "$STUB_WORKTREE/.tmp/finalize.txt"
echo "Issue 123 resolved" >> "$STUB_WORKTREE/.tmp/finalize.txt"

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed and append closes line"
}

# Verify closes line was appended
if ! grep -qi "closes #123" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected 'Closes #123' to be appended to PR body"
fi

# Count occurrences - should be exactly 1
CLOSES_COUNT=$(grep -oi "closes #123" "$GH_CALL_LOG" | wc -l | tr -d ' ')
if [ "$CLOSES_COUNT" -ne 1 ]; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected exactly one 'Closes #123' in PR body (got $CLOSES_COUNT)"
fi

# ── Test 15: Sync fetch/rebase happens before iterations ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
ACW_COMPLETION_ITER=1
export ACW_COMPLETION_ITER

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with sync before iterations"
}

FETCH_LINE=$(grep -n "git fetch" "$CALL_ORDER_LOG" | head -n1 | cut -d: -f1)
REBASE_LINE=$(grep -n "git rebase" "$CALL_ORDER_LOG" | head -n1 | cut -d: -f1)
ACW_LINE=$(grep -n "^acw " "$CALL_ORDER_LOG" | head -n1 | cut -d: -f1)
if [ -z "$FETCH_LINE" ] || [ -z "$REBASE_LINE" ] || [ -z "$ACW_LINE" ]; then
    echo "Call order log:" >&2
    cat "$CALL_ORDER_LOG" >&2
    test_fail "Expected git fetch/rebase and acw calls in order log"
fi
if [ "$FETCH_LINE" -ge "$ACW_LINE" ] || [ "$REBASE_LINE" -ge "$ACW_LINE" ]; then
    echo "Call order log:" >&2
    cat "$CALL_ORDER_LOG" >&2
    test_fail "Expected sync to happen before the first acw call"
fi

# ── Test 16: Sync rebase uses upstream/master ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
GIT_REMOTES=$'upstream\norigin'
GIT_DEFAULT_BRANCH="master"
export GIT_REMOTES GIT_DEFAULT_BRANCH
ACW_COMPLETION_ITER=1
export ACW_COMPLETION_ITER

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with upstream/master sync"
}

if ! grep -q "git fetch upstream" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git fetch upstream"
fi
if ! grep -q "git rebase upstream/master" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git rebase upstream/master"
fi

# ── Test 17: Sync rebase falls back to origin/main ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
GIT_REMOTES="origin"
GIT_DEFAULT_BRANCH="main"
export GIT_REMOTES GIT_DEFAULT_BRANCH
ACW_COMPLETION_ITER=1
export ACW_COMPLETION_ITER

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with origin/main sync"
}

if ! grep -q "git fetch origin" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git fetch origin"
fi
if ! grep -q "git rebase origin/main" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git rebase origin/main"
fi

# ── Test 18: Sync fetch failure stops execution ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
GIT_FETCH_FAILS=1
export GIT_FETCH_FAILS

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) && {
    echo "Output: $output" >&2
    test_fail "lol impl should fail when git fetch fails"
}

echo "$output" | grep -qi "failed to fetch" || {
    echo "Output: $output" >&2
    test_fail "Expected fetch failure error"
}

if grep -q "^acw " "$ACW_CALL_LOG"; then
    echo "ACW call log:" >&2
    cat "$ACW_CALL_LOG" >&2
    test_fail "Expected no acw calls when fetch fails"
fi

# ── Test 19: Sync rebase conflict stops execution ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
GIT_REBASE_FAILS=1
export GIT_REBASE_FAILS

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) && {
    echo "Output: $output" >&2
    test_fail "lol impl should fail when git rebase conflicts"
}

echo "$output" | grep -qi "rebase conflict" || {
    echo "Output: $output" >&2
    test_fail "Expected rebase conflict error"
}

if grep -q "^acw " "$ACW_CALL_LOG"; then
    echo "ACW call log:" >&2
    cat "$ACW_CALL_LOG" >&2
    test_fail "Expected no acw calls when rebase fails"
fi

test_pass "lol impl workflow with stubbed dependencies"
