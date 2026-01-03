#!/usr/bin/env bash
set -euo pipefail

# Test: Milestone resume hint behavior
# Validates that session-init hook displays resume hints when appropriate

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test utilities if available
if [[ -f "$SCRIPT_DIR/test-utils.sh" ]]; then
    source "$SCRIPT_DIR/test-utils.sh"
fi

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Helper: Create temporary git repo with milestone
create_test_repo() {
    local test_dir="$1"
    local issue_num="$2"
    local milestone_num="$3"
    local branch_name="issue-$issue_num-test-feature"

    mkdir -p "$test_dir"
    cd "$test_dir"

    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Create initial commit
    echo "# Test Repo" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Create and switch to issue branch
    git checkout -q -b "$branch_name"

    # Create milestone directory and file
    mkdir -p .milestones
    cat > ".milestones/issue-$issue_num-milestone-$milestone_num.md" <<EOF
# Milestone $milestone_num for Issue #$issue_num

**Branch:** $branch_name
**Created:** $(date '+%Y-%m-%d %H:%M:%S')
**LOC Implemented:** ~500 lines
**Test Status:** 3/8 tests passed

## Work Remaining
- Implement remaining features
EOF

    echo "$branch_name"
}

# Helper: Run resume hint script
run_resume_hint() {
    local repo_dir="$1"
    cd "$repo_dir"
    bash "$PROJECT_ROOT/.claude/hooks/milestone-resume-hint.sh" 2>&1 || true
}

# Test 1: CLAUDE_HANDSOFF=true with issue branch and milestone shows hint
test_handsoff_true_with_milestone() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local test_name="CLAUDE_HANDSOFF=true with milestone shows hint"

    local test_dir=$(mktemp -d)
    trap "rm -rf '$test_dir'" EXIT

    local branch_name=$(create_test_repo "$test_dir" 42 2)

    export CLAUDE_HANDSOFF=true
    local output=$(run_resume_hint "$test_dir")
    unset CLAUDE_HANDSOFF

    if echo "$output" | grep -q "milestone-2" && \
       echo "$output" | grep -q "issue-42" && \
       echo "$output" | grep -q "Continue from the latest milestone"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $test_name"
    else
        echo "✗ $test_name"
        echo "  Expected hint with milestone info, got:"
        echo "$output" | sed 's/^/  /'
    fi
}

# Test 2: CLAUDE_HANDSOFF=false shows no hint
test_handsoff_false_no_hint() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local test_name="CLAUDE_HANDSOFF=false shows no hint"

    local test_dir=$(mktemp -d)
    trap "rm -rf '$test_dir'" EXIT

    create_test_repo "$test_dir" 42 2 > /dev/null

    export CLAUDE_HANDSOFF=false
    local output=$(run_resume_hint "$test_dir")
    unset CLAUDE_HANDSOFF

    if [[ -z "$output" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $test_name"
    else
        echo "✗ $test_name"
        echo "  Expected no output, got:"
        echo "$output" | sed 's/^/  /'
    fi
}

# Test 3: CLAUDE_HANDSOFF unset shows no hint
test_handsoff_unset_no_hint() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local test_name="CLAUDE_HANDSOFF unset shows no hint"

    local test_dir=$(mktemp -d)
    trap "rm -rf '$test_dir'" EXIT

    create_test_repo "$test_dir" 42 2 > /dev/null

    unset CLAUDE_HANDSOFF
    local output=$(run_resume_hint "$test_dir")

    if [[ -z "$output" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $test_name"
    else
        echo "✗ $test_name"
        echo "  Expected no output, got:"
        echo "$output" | sed 's/^/  /'
    fi
}

# Test 4: Non-issue branch shows no hint
test_non_issue_branch_no_hint() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local test_name="Non-issue branch shows no hint"

    local test_dir=$(mktemp -d)
    trap "rm -rf '$test_dir'" EXIT

    create_test_repo "$test_dir" 42 2 > /dev/null
    cd "$test_dir"
    git checkout -q -b "feature-branch" 2>/dev/null || git checkout -q "feature-branch"

    export CLAUDE_HANDSOFF=true
    local output=$(run_resume_hint "$test_dir")
    unset CLAUDE_HANDSOFF

    if [[ -z "$output" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $test_name"
    else
        echo "✗ $test_name"
        echo "  Expected no output on non-issue branch, got:"
        echo "$output" | sed 's/^/  /'
    fi
}

# Test 5: Multiple milestones selects latest
test_multiple_milestones_latest() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local test_name="Multiple milestones selects latest"

    local test_dir=$(mktemp -d)
    trap "rm -rf '$test_dir'" EXIT

    create_test_repo "$test_dir" 42 2 > /dev/null
    cd "$test_dir"

    # Create additional milestones
    cat > ".milestones/issue-42-milestone-3.md" <<EOF
# Milestone 3 for Issue #42
**LOC Implemented:** ~800 lines
EOF

    export CLAUDE_HANDSOFF=true
    local output=$(run_resume_hint "$test_dir")
    unset CLAUDE_HANDSOFF

    if echo "$output" | grep -q "milestone-3" && \
       ! echo "$output" | grep -q "milestone-2"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $test_name"
    else
        echo "✗ $test_name"
        echo "  Expected milestone-3 (latest), got:"
        echo "$output" | sed 's/^/  /'
    fi
}

# Test 6: Invalid CLAUDE_HANDSOFF value (fail-closed)
test_invalid_handsoff_no_hint() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local test_name="Invalid CLAUDE_HANDSOFF value shows no hint"

    local test_dir=$(mktemp -d)
    trap "rm -rf '$test_dir'" EXIT

    create_test_repo "$test_dir" 42 2 > /dev/null

    export CLAUDE_HANDSOFF=invalid
    local output=$(run_resume_hint "$test_dir")
    unset CLAUDE_HANDSOFF

    if [[ -z "$output" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $test_name"
    else
        echo "✗ $test_name"
        echo "  Expected no output for invalid value, got:"
        echo "$output" | sed 's/^/  /'
    fi
}

# Test 7: No milestone files shows no hint
test_no_milestone_no_hint() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local test_name="No milestone files shows no hint"

    local test_dir=$(mktemp -d)
    trap "rm -rf '$test_dir'" EXIT

    # Create repo without milestones
    cd "$test_dir"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "# Test" > README.md
    git add README.md
    git commit -q -m "Initial"
    git checkout -q -b "issue-42-test"

    export CLAUDE_HANDSOFF=true
    local output=$(run_resume_hint "$test_dir")
    unset CLAUDE_HANDSOFF

    if [[ -z "$output" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $test_name"
    else
        echo "✗ $test_name"
        echo "  Expected no output without milestone files, got:"
        echo "$output" | sed 's/^/  /'
    fi
}

# Run all tests
echo "Running milestone resume hint tests..."
echo

test_handsoff_true_with_milestone
test_handsoff_false_no_hint
test_handsoff_unset_no_hint
test_non_issue_branch_no_hint
test_multiple_milestones_latest
test_invalid_handsoff_no_hint
test_no_milestone_no_hint

echo
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
