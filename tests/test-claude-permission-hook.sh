#!/usr/bin/env bash
set -e

# Test suite for .claude/hooks/permission-request.sh
# Tests CLAUDE_HANDSOFF environment variable behavior

# Get project root using shell-neutral approach
PROJECT_ROOT="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"
if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: Cannot determine project root. Set AGENTIZE_HOME or run from git repo."
  exit 1
fi
HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"

# Test helper: run hook and capture decision
run_hook() {
    local tool="$1"
    local description="$2"
    shift 2

    # Hook receives: tool, description, additional args as JSON
    "$HOOK_SCRIPT" "$tool" "$description" "$@"
}

# Test 1: CLAUDE_HANDSOFF=true + safe read → allow
test_handsoff_true_safe_read() {
    echo "Test 1: CLAUDE_HANDSOFF=true with safe read operation"
    export CLAUDE_HANDSOFF=true

    local result
    result=$(run_hook "Read" "Read configuration file" '{"file_path": "/tmp/test.txt"}')

    if [[ "$result" == "allow" ]]; then
        echo "✓ PASS: Safe read auto-allowed in hands-off mode"
    else
        echo "✗ FAIL: Expected 'allow', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 2: CLAUDE_HANDSOFF=false + safe read → ask
test_handsoff_false_safe_read() {
    echo "Test 2: CLAUDE_HANDSOFF=false with safe read operation"
    export CLAUDE_HANDSOFF=false

    local result
    result=$(run_hook "Read" "Read configuration file" '{"file_path": "/tmp/test.txt"}')

    if [[ "$result" == "ask" ]]; then
        echo "✓ PASS: Safe read asks permission when hands-off is disabled"
    else
        echo "✗ FAIL: Expected 'ask', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 3: CLAUDE_HANDSOFF=invalid + safe read → ask (fail-closed)
test_handsoff_invalid_safe_read() {
    echo "Test 3: CLAUDE_HANDSOFF=invalid with safe read operation"
    export CLAUDE_HANDSOFF=maybe

    local result
    result=$(run_hook "Read" "Read configuration file" '{"file_path": "/tmp/test.txt"}')

    if [[ "$result" == "ask" ]]; then
        echo "✓ PASS: Invalid value treated as disabled (fail-closed)"
    else
        echo "✗ FAIL: Expected 'ask', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 4: CLAUDE_HANDSOFF=TRUE (uppercase) + safe read → allow (case-insensitive)
test_handsoff_case_insensitive() {
    echo "Test 4: CLAUDE_HANDSOFF=TRUE (case-insensitive)"
    export CLAUDE_HANDSOFF=TRUE

    local result
    result=$(run_hook "Read" "Read configuration file" '{"file_path": "/tmp/test.txt"}')

    if [[ "$result" == "allow" ]]; then
        echo "✓ PASS: Case-insensitive parsing works"
    else
        echo "✗ FAIL: Expected 'allow', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 5: CLAUDE_HANDSOFF=true + destructive bash → deny or ask
test_handsoff_true_destructive() {
    echo "Test 5: CLAUDE_HANDSOFF=true with destructive operation"
    export CLAUDE_HANDSOFF=true

    local result
    result=$(run_hook "Bash" "Delete all files" '{"command": "rm -rf /"}')

    if [[ "$result" == "deny" || "$result" == "ask" ]]; then
        echo "✓ PASS: Destructive operation not auto-allowed ($result)"
    else
        echo "✗ FAIL: Expected 'deny' or 'ask', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 6: Unset env var + safe read → ask (fail-closed)
test_handsoff_unset() {
    echo "Test 6: CLAUDE_HANDSOFF unset with safe read operation"
    unset CLAUDE_HANDSOFF

    local result
    result=$(run_hook "Read" "Read configuration file" '{"file_path": "/tmp/test.txt"}')

    if [[ "$result" == "ask" ]]; then
        echo "✓ PASS: Unset env var results in 'ask' (fail-closed)"
    else
        echo "✗ FAIL: Expected 'ask', got '$result'"
        exit 1
    fi
}

# Test 7: CLAUDE_HANDSOFF=true + Edit → allow
test_handsoff_true_edit() {
    echo "Test 7: CLAUDE_HANDSOFF=true with Edit operation"
    export CLAUDE_HANDSOFF=true

    local result
    result=$(run_hook "Edit" "Update configuration file" '{"file_path": "/tmp/test.txt", "old_string": "foo", "new_string": "bar"}')

    if [[ "$result" == "allow" ]]; then
        echo "✓ PASS: Edit auto-allowed in hands-off mode"
    else
        echo "✗ FAIL: Expected 'allow', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 8: CLAUDE_HANDSOFF=true + Write → allow
test_handsoff_true_write() {
    echo "Test 8: CLAUDE_HANDSOFF=true with Write operation"
    export CLAUDE_HANDSOFF=true

    local result
    result=$(run_hook "Write" "Create new file" '{"file_path": "/tmp/test.txt", "content": "test content"}')

    if [[ "$result" == "allow" ]]; then
        echo "✓ PASS: Write auto-allowed in hands-off mode"
    else
        echo "✗ FAIL: Expected 'allow', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 9: CLAUDE_HANDSOFF=true + safe git command → allow
test_handsoff_true_safe_git() {
    echo "Test 9: CLAUDE_HANDSOFF=true with safe git command"
    export CLAUDE_HANDSOFF=true

    local result
    result=$(run_hook "Bash" "Check git status" '{"command": "git status"}')

    if [[ "$result" == "allow" ]]; then
        echo "✓ PASS: Safe git command auto-allowed in hands-off mode"
    else
        echo "✗ FAIL: Expected 'allow', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 10: CLAUDE_HANDSOFF=true + git commit → allow
test_handsoff_true_git_commit() {
    echo "Test 10: CLAUDE_HANDSOFF=true with git commit"
    export CLAUDE_HANDSOFF=true

    local result
    result=$(run_hook "Bash" "Create commit" '{"command": "git commit -m \"test\""}')

    if [[ "$result" == "allow" ]]; then
        echo "✓ PASS: Git commit auto-allowed in hands-off mode"
    else
        echo "✗ FAIL: Expected 'allow', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 11: CLAUDE_HANDSOFF=true + git push → ask (publish operation)
test_handsoff_true_git_push() {
    echo "Test 11: CLAUDE_HANDSOFF=true with git push (publish operation)"
    export CLAUDE_HANDSOFF=true

    local result
    result=$(run_hook "Bash" "Push to remote" '{"command": "git push"}')

    if [[ "$result" == "ask" || "$result" == "deny" ]]; then
        echo "✓ PASS: Git push not auto-allowed ($result)"
    else
        echo "✗ FAIL: Expected 'ask' or 'deny', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 12: CLAUDE_HANDSOFF=true + gh pr create → ask (publish operation)
test_handsoff_true_gh_pr_create() {
    echo "Test 12: CLAUDE_HANDSOFF=true with gh pr create (publish operation)"
    export CLAUDE_HANDSOFF=true

    local result
    result=$(run_hook "Bash" "Create pull request" '{"command": "gh pr create --title \"test\""}')

    if [[ "$result" == "ask" || "$result" == "deny" ]]; then
        echo "✓ PASS: PR creation not auto-allowed ($result)"
    else
        echo "✗ FAIL: Expected 'ask' or 'deny', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 13: CLAUDE_HANDSOFF=true + test command → allow
test_handsoff_true_test_command() {
    echo "Test 13: CLAUDE_HANDSOFF=true with test command"
    export CLAUDE_HANDSOFF=true

    local result
    result=$(run_hook "Bash" "Run tests" '{"command": "make test"}')

    if [[ "$result" == "allow" ]]; then
        echo "✓ PASS: Test command auto-allowed in hands-off mode"
    else
        echo "✗ FAIL: Expected 'allow', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Test 14: CLAUDE_HANDSOFF=false + Edit → ask
test_handsoff_false_edit() {
    echo "Test 14: CLAUDE_HANDSOFF=false with Edit operation"
    export CLAUDE_HANDSOFF=false

    local result
    result=$(run_hook "Edit" "Update configuration file" '{"file_path": "/tmp/test.txt", "old_string": "foo", "new_string": "bar"}')

    if [[ "$result" == "ask" ]]; then
        echo "✓ PASS: Edit asks permission when hands-off is disabled"
    else
        echo "✗ FAIL: Expected 'ask', got '$result'"
        exit 1
    fi

    unset CLAUDE_HANDSOFF
}

# Run all tests
main() {
    echo "=== Running permission hook tests ==="
    echo

    test_handsoff_true_safe_read
    echo
    test_handsoff_false_safe_read
    echo
    test_handsoff_invalid_safe_read
    echo
    test_handsoff_case_insensitive
    echo
    test_handsoff_true_destructive
    echo
    test_handsoff_unset
    echo
    test_handsoff_true_edit
    echo
    test_handsoff_true_write
    echo
    test_handsoff_true_safe_git
    echo
    test_handsoff_true_git_commit
    echo
    test_handsoff_true_git_push
    echo
    test_handsoff_true_gh_pr_create
    echo
    test_handsoff_true_test_command
    echo
    test_handsoff_false_edit
    echo

    echo "=== All tests passed ==="
}

main
