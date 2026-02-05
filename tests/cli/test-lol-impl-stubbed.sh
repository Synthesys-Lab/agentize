#!/usr/bin/env bash
# Test: lol impl workflow with stubbed wt, acw, and gh via overrides
# Validates core lol impl contract with minimal stubbed checks

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
ACW_CALL_LOG="$TMP_DIR/acw-calls.log"
GH_CALL_LOG="$TMP_DIR/gh-calls.log"
GIT_CALL_LOG="$TMP_DIR/git-calls.log"
touch "$ACW_CALL_LOG" "$GH_CALL_LOG" "$GIT_CALL_LOG"

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
}

log_acw_call() {
    echo "acw $*" >> "$ACW_CALL_LOG"
}

wt() {
    case "$1" in
        pathto)
            echo "$STUB_WORKTREE"
            return 0
            ;;
        spawn)
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
kimi
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
export STUB_WORKTREE ACW_CALL_LOG GH_CALL_LOG GIT_CALL_LOG
export ITERATION_COUNT_FILE

# Source overrides so shell-level wt calls also use stubs
source "$OVERRIDES"

reset_iteration() {
    echo 0 > "$ITERATION_COUNT_FILE"
}

reset_logs() {
    : > "$ACW_CALL_LOG"
    : > "$GH_CALL_LOG"
    : > "$GIT_CALL_LOG"
}

reset_stub_state() {
    reset_iteration
    reset_logs
    unset ACW_COMPLETION_ITER
    unset ACW_WRITE_COMMIT_REPORT
    unset ACW_FINALIZE_CONTENT
    unset ACW_OUTPUT_TEXT
    unset GH_FAIL_ISSUE_VIEW
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

# ── Test 2: Issue prefetch success writes issue file ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
ACW_COMPLETION_ITER=1
export ACW_COMPLETION_ITER
rm -f "$STUB_WORKTREE/.tmp/issue-123.md"

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed with issue prefetch"
}

grep -q "gh issue view 123" "$GH_CALL_LOG" || {
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh issue view to be called for prefetch"
}

if [ ! -f "$STUB_WORKTREE/.tmp/issue-123.md" ]; then
    test_fail "Expected .tmp/issue-123.md to be created"
fi

# ── Test 3: Issue prefetch failure stops execution ──
reset_stub_state
STUB_ISSUE_NO=456
export STUB_ISSUE_NO
GH_FAIL_ISSUE_VIEW=1
export GH_FAIL_ISSUE_VIEW

output=$(lol impl 456 --backend codex:gpt-5.2-codex 2>&1) && {
    echo "Output: $output" >&2
    test_fail "lol impl should fail when prefetch fails"
}

echo "$output" | grep -qi "failed to fetch issue content" || {
    echo "Output: $output" >&2
    test_fail "Expected error about prefetch failure"
}

if grep -q "^acw " "$ACW_CALL_LOG"; then
    echo "ACW call log:" >&2
    cat "$ACW_CALL_LOG" >&2
    test_fail "Expected no acw calls when prefetch fails"
fi

# ── Test 4: Completion marker detection via finalize.txt ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
ACW_COMPLETION_ITER=1
export ACW_COMPLETION_ITER

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed when completion marker appears"
}

if ! grep -q "gh pr create" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh pr create to be called on completion"
fi

# ── Test 5: Commit report required per iteration ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
ACW_COMPLETION_ITER=1
export ACW_COMPLETION_ITER
GIT_HAS_CHANGES=1
export GIT_HAS_CHANGES
find "$STUB_WORKTREE/.tmp" -name 'commit-report-iter-*.txt' -delete 2>/dev/null || true

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) || {
    echo "Output: $output" >&2
    test_fail "lol impl should succeed when commit report exists"
}

if ! grep -q "git commit -F .*commit-report-iter-1.txt" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git commit to use commit-report-iter-1.txt"
fi

# ── Test 6: Missing commit report fails the iteration ──
reset_stub_state
STUB_ISSUE_NO=123
export STUB_ISSUE_NO
ACW_COMPLETION_ITER=1
export ACW_COMPLETION_ITER
ACW_WRITE_COMMIT_REPORT=0
export ACW_WRITE_COMMIT_REPORT
GIT_HAS_CHANGES=1
export GIT_HAS_CHANGES
find "$STUB_WORKTREE/.tmp" -name 'commit-report-iter-*.txt' -delete 2>/dev/null || true

output=$(lol impl 123 --backend codex:gpt-5.2-codex 2>&1) && {
    echo "Output: $output" >&2
    test_fail "lol impl should fail when commit report is missing"
}

echo "$output" | grep -qi "missing commit report" || {
    echo "Output: $output" >&2
    test_fail "Expected missing commit report error"
}

# ── Test 7: Sync fetch failure stops before iterations ──
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

# ── Test 8: Sync rebase conflict stops before iterations ──
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

# ── Test 9: Base branch + remote selection (upstream/master) ──
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
    test_fail "lol impl should succeed with upstream/master"
}

if ! grep -q "git push -u upstream" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git push to use upstream remote"
fi

if ! grep -q "gh pr create.*--base master" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh pr create with --base master"
fi

# ── Test 10: Base branch + remote selection fallback (origin/main) ──
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
    test_fail "lol impl should succeed with origin/main fallback"
}

if ! grep -q "git push -u origin" "$GIT_CALL_LOG"; then
    echo "GIT call log:" >&2
    cat "$GIT_CALL_LOG" >&2
    test_fail "Expected git push to use origin remote"
fi

if ! grep -q "gh pr create.*--base main" "$GH_CALL_LOG"; then
    echo "GH call log:" >&2
    cat "$GH_CALL_LOG" >&2
    test_fail "Expected gh pr create with --base main"
fi

test_pass "lol impl workflow with stubbed dependencies"
