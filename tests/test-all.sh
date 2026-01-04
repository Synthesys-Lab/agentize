#!/bin/bash
# Purpose: Master test runner that executes all Agentize test suites
# Expected: All tests pass (exit 0) or report which tests failed (exit 1)
# Supports: Multi-shell testing via TEST_SHELLS environment variable
# Supports: Category filtering (sdk, cli, lint, handsoff)

set -e

# Get project root using shell-neutral approach
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: Cannot determine project root. Run from git repo."
  exit 1
fi

# Source local setup.sh to ensure AGENTIZE_HOME points to current worktree
# (overrides any inherited AGENTIZE_HOME from parent shell)
if [ -f "$PROJECT_ROOT/setup.sh" ]; then
  source "$PROJECT_ROOT/setup.sh"
else
  # If setup.sh doesn't exist, create it
  (cd "$PROJECT_ROOT" && make setup >/dev/null 2>&1)
  source "$PROJECT_ROOT/setup.sh"
fi

SCRIPT_DIR="$PROJECT_ROOT/tests"

# Detect if TEST_SHELLS was explicitly set (check BEFORE applying default)
EXPLICIT_SHELLS=0
if [ -n "${TEST_SHELLS+x}" ] && [ -n "$TEST_SHELLS" ]; then
  EXPLICIT_SHELLS=1
  EXPLICIT_SHELLS_VALUE="$TEST_SHELLS"
fi

# Default to bash if TEST_SHELLS is not set
TEST_SHELLS="${TEST_SHELLS:-bash}"

# Strict shell enforcement: if TEST_SHELLS was explicitly set, all shells must be available
if [ $EXPLICIT_SHELLS -eq 1 ]; then
  MISSING_SHELLS=""
  for shell in $EXPLICIT_SHELLS_VALUE; do
    if ! command -v "$shell" >/dev/null 2>&1; then
      if [ -z "$MISSING_SHELLS" ]; then
        MISSING_SHELLS="$shell"
      else
        MISSING_SHELLS="$MISSING_SHELLS, $shell"
      fi
    fi
  done

  if [ -n "$MISSING_SHELLS" ]; then
    echo "======================================"
    echo "Error: Required shells not found"
    echo "======================================"
    echo ""
    echo "TEST_SHELLS was explicitly set to: $EXPLICIT_SHELLS_VALUE"
    echo "Missing shells: $MISSING_SHELLS"
    echo ""
    echo "To fix this issue:"
    echo "  - Install the missing shell(s)"
    echo "  - Or unset TEST_SHELLS to use default (bash only)"
    echo ""
    exit 1
  fi
fi

# Parse optional category arguments (sdk, cli, lint, handsoff)
# If no arguments provided, run all categories
if [ $# -eq 0 ]; then
  CATEGORIES="sdk cli lint handsoff"
else
  CATEGORIES="$@"
fi

# Function to check if test should be skipped (hook tests skip in zsh)
should_skip_test() {
    local shell="$1"
    local test_script="$2"
    local test_name=$(basename "$test_script" .sh)

    # Hook tests only run in bash (Claude Code invokes hooks with bash only)
    if [ "$shell" = "zsh" ]; then
        case "$test_name" in
            test-hook-*|test-milestone-resume-hint|test-refine-issue-extract-plan|test-worktree-env-override-title-length)
                return 0  # Should skip
                ;;
        esac
    fi

    return 1  # Should not skip
}

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
    # Shell availability already validated in strict mode
    # In non-strict mode (TEST_SHELLS not explicitly set), skip missing shells
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

            # Skip hook tests when running in zsh
            if should_skip_test "$shell" "$test_file"; then
                test_name=$(basename "$test_file" .sh)
                echo "✓ $test_name (skipped: hook tests only run in bash)"
                TOTAL_TESTS=$((TOTAL_TESTS + 1))
                PASSED_TESTS=$((PASSED_TESTS + 1))
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
