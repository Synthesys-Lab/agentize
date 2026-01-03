#!/bin/bash
# Purpose: Master test runner that executes all Agentize test suites
# Expected: All tests pass (exit 0) or report which tests failed (exit 1)

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "Running all Agentize SDK tests"
echo "======================================"
echo ""

# Track test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test Agentize mode validation
echo ">>> Testing Agentize mode validation..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-agentize-modes.sh"; then
    echo "✓ Agentize mode validation tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ Agentize mode validation tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Test Makefile parameter validation logic
echo ">>> Testing Makefile parameter validation..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-makefile-validation.sh"; then
    echo "✓ Makefile validation tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ Makefile validation tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Test C SDK
echo ">>> Testing C SDK..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-c-sdk.sh"; then
    echo "✓ C SDK tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ C SDK tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Test C++ SDK
echo ">>> Testing C++ SDK..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-cxx-sdk.sh"; then
    echo "✓ C++ SDK tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ C++ SDK tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Test Python SDK (TODO)
echo ">>> Testing Python SDK..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ -s "$SCRIPT_DIR/test-python-sdk.sh" ]; then
    if bash "$SCRIPT_DIR/test-python-sdk.sh"; then
        echo "✓ Python SDK tests passed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "✗ Python SDK tests failed"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo "⊘ Python SDK tests not yet implemented (skipping)"
    TOTAL_TESTS=$((TOTAL_TESTS - 1))
fi
echo ""

# Test Worktree functionality
echo ">>> Testing Worktree functionality..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-worktree.sh"; then
    echo "✓ Worktree tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ Worktree tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Test Cross-Project wt Function
echo ">>> Testing Cross-Project wt function..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-wt-cross-project.sh"; then
    echo "✓ Cross-project wt tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ Cross-project wt tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Test Agentize CLI Function
echo ">>> Testing Agentize CLI function..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-agentize-cli.sh"; then
    echo "✓ Agentize CLI tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ Agentize CLI tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Test BASH_SOURCE Removal
echo ">>> Testing BASH_SOURCE removal..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-bash-source-removal.sh"; then
    echo "✓ BASH_SOURCE removal tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ BASH_SOURCE removal tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Test lol project command
echo ">>> Testing lol project command..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-lol-project.sh"; then
    echo "✓ lol project tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ lol project tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Commands & Skills Tests
echo ">>> Testing /refine-issue command..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-refine-issue.sh"; then
    echo "✓ /refine-issue command tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ /refine-issue command tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

echo ">>> Testing open-issue --draft flag..."
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if bash "$SCRIPT_DIR/test-open-issue-draft.sh"; then
    echo "✓ open-issue --draft tests passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "✗ open-issue --draft tests failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Print summary
echo "======================================"
echo "Test Summary"
echo "======================================"
echo "Total:  $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo "======================================"

if [ $FAILED_TESTS -gt 0 ]; then
    echo "Some tests failed!"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
