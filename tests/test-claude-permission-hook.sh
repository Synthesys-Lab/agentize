#!/usr/bin/env bash
set -e

# Test suite for .claude/hooks/permission-request.sh
# Tests CLAUDE_HANDSOFF environment variable behavior

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

    echo "=== All tests passed ==="
}

main
