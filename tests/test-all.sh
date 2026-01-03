#!/bin/bash
# Purpose: Master test runner that executes all Agentize test suites
# Expected: All tests pass (exit 0) or report which tests failed (exit 1)
# Supports: Multi-shell testing via TEST_SHELLS environment variable
# Supports: Category filtering (sdk, cli, lint, handsoff)

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

# Parse optional category arguments (sdk, cli, lint, handsoff)
# If no arguments provided, run all categories
if [ $# -eq 0 ]; then
  CATEGORIES="sdk cli lint handsoff"
else
  CATEGORIES="$@"
fi

# Function to run a test with a specific shell
run_test() {
    local shell="$1"
    local test_script="$2"
    local test_name=$(basename "$test_script" .sh)

    if "$shell" "$test_script" > /dev/null 2>&1; then
        echo "✓ $test_name"
        return 0
    else
        echo "✗ $test_name FAILED"
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

    # Auto-discover and run tests in categorical subdirectories
    for category in $CATEGORIES; do
        category_dir="$SCRIPT_DIR/$category"

        # Skip if category directory doesn't exist
        if [ ! -d "$category_dir" ]; then
            continue
        fi

        # Find all test-*.sh files in this category
        for test_file in "$category_dir"/test-*.sh; do
            # Skip if it doesn't exist (glob didn't match)
            if [ ! -f "$test_file" ]; then
                continue
            fi

            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            if run_test "$shell" "$test_file"; then
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
        done
    done

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
