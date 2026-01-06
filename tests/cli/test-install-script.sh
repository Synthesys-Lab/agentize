#!/usr/bin/env bash

# Test: scripts/install installer script
#
# Test cases:
# 1. Successful install from local repo path creates trees/main and setup.sh
# 2. Re-run when install dir exists exits non-zero with clear message

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SCRIPT="$PROJECT_ROOT/scripts/install"

# Test utilities
TEST_PASSED=0
TEST_FAILED=0

pass() {
    echo "[PASS] $1"
    TEST_PASSED=$((TEST_PASSED + 1))
}

fail() {
    echo "[FAIL] $1"
    TEST_FAILED=$((TEST_FAILED + 1))
}

# Test case 1: Successful install from local repo path
test_successful_install() {
    echo "Test 1: Successful install from local repo path"

    local test_dir="$PROJECT_ROOT/.tmp/test-install-$$"

    # Clean up any previous test runs
    rm -rf "$test_dir"

    # Run installer with local repo path
    if "$INSTALL_SCRIPT" --repo "$PROJECT_ROOT" --dir "$test_dir" >/dev/null 2>&1; then
        # Check that trees/main was created
        if [ -d "$test_dir/trees/main" ]; then
            pass "trees/main directory created"
        else
            fail "trees/main directory not created"
        fi

        # Check that setup.sh was generated
        if [ -f "$test_dir/trees/main/setup.sh" ]; then
            pass "setup.sh generated in trees/main"
        else
            fail "setup.sh not generated in trees/main"
        fi

        # Check that AGENTIZE_HOME is set in setup.sh
        if grep -q "AGENTIZE_HOME" "$test_dir/trees/main/setup.sh"; then
            pass "AGENTIZE_HOME exported in setup.sh"
        else
            fail "AGENTIZE_HOME not found in setup.sh"
        fi
    else
        fail "Installer failed to complete"
    fi

    # Clean up
    rm -rf "$test_dir"
}

# Test case 2: Re-run when install dir exists fails
test_install_dir_exists() {
    echo "Test 2: Re-run when install dir exists exits non-zero"

    local test_dir="$PROJECT_ROOT/.tmp/test-install-exists-$$"

    # Clean up any previous test runs
    rm -rf "$test_dir"

    # First install
    "$INSTALL_SCRIPT" --repo "$PROJECT_ROOT" --dir "$test_dir" >/dev/null 2>&1

    # Second install should fail
    if "$INSTALL_SCRIPT" --repo "$PROJECT_ROOT" --dir "$test_dir" 2>/dev/null; then
        fail "Installer should fail when directory exists"
    else
        pass "Installer correctly fails when directory exists"

        # Check for helpful error message
        local error_output
        error_output=$("$INSTALL_SCRIPT" --repo "$PROJECT_ROOT" --dir "$test_dir" 2>&1 || true)

        if echo "$error_output" | grep -qi "already exists\|directory exists"; then
            pass "Error message mentions directory exists"
        else
            fail "Error message should mention directory exists"
        fi
    fi

    # Clean up
    rm -rf "$test_dir"
}

# Run all tests
test_successful_install
test_install_dir_exists

# Summary
echo ""
echo "=========================================="
echo "Test Summary:"
echo "  Passed: $TEST_PASSED"
echo "  Failed: $TEST_FAILED"
echo "=========================================="

if [ "$TEST_FAILED" -gt 0 ]; then
    exit 1
fi

exit 0
