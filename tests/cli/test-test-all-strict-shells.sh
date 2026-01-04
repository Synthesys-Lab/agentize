#!/bin/bash
# Test strict shell enforcement when TEST_SHELLS is explicitly set

source "$(dirname "$0")/../common.sh"

test_info "Testing strict shell enforcement for missing shells"

# Create a temporary directory for test output
TMP_DIR=$(make_temp_dir "test-strict-shells")

# Test 1: Explicitly set TEST_SHELLS with a non-existent shell
test_info "Running test-all.sh with TEST_SHELLS containing missing shell"

# Use a non-existent category to avoid recursively running other tests
# The strict shell check should fail before attempting to run tests
# Temporarily disable set -e to capture exit code
set +e
TEST_SHELLS="bash definitely_missing_shell_xyz" "$PROJECT_ROOT/tests/test-all.sh" nonexistent_category > "$TMP_DIR/output.txt" 2>&1
EXIT_CODE=$?
set -e

test_info "Exit code: $EXIT_CODE"
test_info "Output:"
cat "$TMP_DIR/output.txt"

# Verify that the script exited with error
if [ $EXIT_CODE -eq 0 ]; then
  cleanup_dir "$TMP_DIR"
  test_fail "test-all.sh should exit with non-zero when missing required shell"
fi

# Verify error message mentions the missing shell
if ! grep -q "definitely_missing_shell_xyz" "$TMP_DIR/output.txt"; then
  cleanup_dir "$TMP_DIR"
  test_fail "Error message should mention the missing shell"
fi

# Verify error message is clear about the requirement
if ! grep -qi "not found\|missing\|unavailable\|required" "$TMP_DIR/output.txt"; then
  cleanup_dir "$TMP_DIR"
  test_fail "Error message should clearly indicate the shell is missing/required"
fi

# Test 2: Verify bash-only (default) still works
test_info "Verifying default bash-only behavior still works"
unset TEST_SHELLS
set +e
"$PROJECT_ROOT/tests/test-all.sh" nonexistent_category > "$TMP_DIR/output2.txt" 2>&1
EXIT_CODE2=$?
set -e

# Should exit cleanly (no tests found is OK, but shell validation should pass)
# Exit code may be non-zero if no tests found, but should not be shell-related error
if grep -qi "shell.*not found\|shell.*missing" "$TMP_DIR/output2.txt"; then
  cleanup_dir "$TMP_DIR"
  test_fail "Default bash-only mode should not fail on shell availability"
fi

cleanup_dir "$TMP_DIR"
test_pass "Strict shell enforcement works correctly"
