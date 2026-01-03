#!/bin/bash
# Purpose: Master test runner that executes all Agentize test suites
# Expected: All tests pass (exit 0) or report which tests failed (exit 1)
# Supports: Multi-shell testing via TEST_SHELLS environment variable

set -e

# Get project root using shell-neutral approach
PROJECT_ROOT="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"
if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: Cannot determine project root. Set AGENTIZE_HOME or run from git repo."
  exit 1
fi
SCRIPT_DIR="$PROJECT_ROOT/tests"

# Default to bash if TEST_SHELLS is not set
TEST_SHELLS="${TEST_SHELLS:-bash}"

# List of all test scripts
TEST_SCRIPTS=(
    "test-agentize-modes.sh"
    "test-makefile-validation.sh"
    "test-c-sdk.sh"
    "test-cxx-sdk.sh"
    "test-python-sdk.sh"
    "test-worktree.sh"
    "test-wt-cross-project.sh"
    "test-agentize-cli.sh"
    "test-bash-source-removal.sh"
    "test-lol-project.sh"
    "test-refine-issue.sh"
    "test-open-issue-draft.sh"
    "test-claude-permission-hook.sh"
)

# Function to run a test with a specific shell
run_test() {
    local shell="$1"
    local test_script="$2"
    local test_name="$3"

    if "$shell" "$SCRIPT_DIR/$test_script"; then
        echo "✓ $test_name passed"
        return 0
    else
        echo "✗ $test_name failed"
        return 1
    fi
}

# Main execution
GLOBAL_FAILED=0

for shell in $TEST_SHELLS; do
    # Check if shell is available
    if ! command -v "$shell" >/dev/null 2>&1; then
        echo "======================================"
        echo "Warning: Shell '$shell' not found, skipping"
        echo "======================================"
        echo ""
        continue
    fi

    echo "======================================"
    echo "Running all Agentize SDK tests"
    echo "Shell: $shell"
    echo "======================================"
    echo ""

    # Track test results for this shell
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0

    # Test Agentize mode validation
    echo ">>> Testing Agentize mode validation..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-agentize-modes.sh" "Agentize mode validation tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    # Test Makefile parameter validation logic
    echo ">>> Testing Makefile parameter validation..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-makefile-validation.sh" "Makefile validation tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    # Test C SDK
    echo ">>> Testing C SDK..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-c-sdk.sh" "C SDK tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    # Test C++ SDK
    echo ">>> Testing C++ SDK..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-cxx-sdk.sh" "C++ SDK tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    # Test Python SDK
    echo ">>> Testing Python SDK..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ -s "$SCRIPT_DIR/test-python-sdk.sh" ]; then
        if run_test "$shell" "test-python-sdk.sh" "Python SDK tests"; then
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
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
    if run_test "$shell" "test-worktree.sh" "Worktree tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    # Test Cross-Project wt Function
    echo ">>> Testing Cross-Project wt function..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-wt-cross-project.sh" "Cross-project wt tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    # Test Agentize CLI Function
    echo ">>> Testing Agentize CLI function..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-agentize-cli.sh" "Agentize CLI tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    # Test BASH_SOURCE Removal
    echo ">>> Testing BASH_SOURCE removal..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-bash-source-removal.sh" "BASH_SOURCE removal tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    # Test lol project command
    echo ">>> Testing lol project command..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-lol-project.sh" "lol project tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    # Commands & Skills Tests
    echo ">>> Testing /refine-issue command..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-refine-issue.sh" "/refine-issue command tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    echo ">>> Testing open-issue --draft flag..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-open-issue-draft.sh" "open-issue --draft tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    echo ">>> Testing Claude permission hook..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if run_test "$shell" "test-claude-permission-hook.sh" "Claude permission hook tests"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""

    # Print summary for this shell
    echo "======================================"
    echo "Test Summary for $shell"
    echo "======================================"
    echo "Total:  $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "======================================"
    echo ""

    if [ $FAILED_TESTS -gt 0 ]; then
        echo "Some tests failed in $shell!"
        GLOBAL_FAILED=1
    else
        echo "All tests passed in $shell!"
    fi
    echo ""
done

# Final exit status
if [ $GLOBAL_FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
