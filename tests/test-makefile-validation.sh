#!/bin/bash
# Purpose: Test suite for Makefile agentize target validation logic
# Expected: Validates mode-specific parameter requirements and git-msg-tags.md handling

set -e

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=6

# Get project root using shell-neutral approach
PROJECT_ROOT="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"
if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: Cannot determine project root. Set AGENTIZE_HOME or run from git repo."
  exit 1
fi

# Helper function to print test status
print_test_header() {
    echo ""
    echo "=================================================="
    echo "TEST: $1"
    echo "=================================================="
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# Helper function to cleanup test directories
cleanup_test_dir() {
    local test_dir="$1"
    if [ -d "$test_dir" ]; then
        rm -rf "$test_dir"
        print_info "Cleaned up test directory: $test_dir"
    fi
}

# Helper function to run make command and capture output
run_make() {
    local output_file="$1"
    shift
    make -C "$PROJECT_ROOT" "$@" > "$output_file" 2>&1
    return $?
}

# Helper function to run script with environment variables and capture output
run_script() {
    local output_file="$1"
    local script="$2"
    shift 2

    # Set environment variables
    while [ $# -gt 0 ]; do
        case "$1" in
            *=*)
                export "$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    "$script" > "$output_file" 2>&1
    return $?
}

#####################################################################
# TC1: Init mode without LANG parameter (should fail)
#####################################################################
test_init_without_lang() {
    print_test_header "TC1: Init mode without LANG parameter (should fail)"

    local test_dir="/tmp/test_init_no_lang_$$"
    local output_file="/tmp/test_output_$$"

    cleanup_test_dir "$test_dir"

    # Run script without AGENTIZE_PROJECT_LANG in init mode
    set +e
    run_script "$output_file" "$PROJECT_ROOT/scripts/agentize-init.sh" \
        AGENTIZE_PROJECT_NAME="test_proj" \
        AGENTIZE_PROJECT_PATH="$test_dir"
    local exit_code=$?
    set -e

    # Verify it failed
    if [ $exit_code -ne 0 ]; then
        # Check error message mentions LANG requirement
        if grep -q "AGENTIZE_PROJECT_LANG" "$output_file"; then
            print_pass "Init mode correctly requires AGENTIZE_PROJECT_LANG parameter"
        else
            print_fail "Error message doesn't mention AGENTIZE_PROJECT_LANG requirement"
            cat "$output_file"
        fi
    else
        print_fail "Init mode should fail without AGENTIZE_PROJECT_LANG, but succeeded"
        cat "$output_file"
    fi

    cleanup_test_dir "$test_dir"
    rm -f "$output_file"
}

#####################################################################
# TC2: Update mode without LANG parameter (should succeed)
#####################################################################
test_update_without_lang() {
    print_test_header "TC2: Update mode without LANG parameter (should succeed)"

    local test_dir="/tmp/test_update_no_lang_$$"
    local output_file="/tmp/test_output_$$"

    cleanup_test_dir "$test_dir"

    # Setup: Create a valid SDK structure first
    print_info "Setting up: Creating initial SDK structure"
    set +e
    run_script "$output_file" "$PROJECT_ROOT/scripts/agentize-init.sh" \
        AGENTIZE_PROJECT_NAME="test_proj" \
        AGENTIZE_PROJECT_PATH="$test_dir" \
        AGENTIZE_PROJECT_LANG="python"
    local setup_exit=$?
    set -e

    if [ $setup_exit -ne 0 ]; then
        print_fail "Setup failed: Could not create initial SDK structure"
        cat "$output_file"
        cleanup_test_dir "$test_dir"
        rm -f "$output_file"
        return
    fi

    # Test: Update without LANG or NAME
    print_info "Testing: Update mode without LANG or NAME parameters"
    set +e
    run_script "$output_file" "$PROJECT_ROOT/scripts/agentize-update.sh" \
        AGENTIZE_PROJECT_PATH="$test_dir"
    local exit_code=$?
    set -e

    # Verify it succeeded
    if [ $exit_code -eq 0 ]; then
        print_pass "Update mode succeeded without AGENTIZE_PROJECT_LANG or NAME"
    else
        print_fail "Update mode should succeed without LANG/NAME, but failed"
        cat "$output_file"
    fi

    cleanup_test_dir "$test_dir"
    rm -f "$output_file"
}

#####################################################################
# TC3: Update mode creates missing git-msg-tags.md
#####################################################################
test_update_creates_git_tags() {
    print_test_header "TC3: Update mode creates missing git-msg-tags.md"

    local test_dir="/tmp/test_update_git_tags_$$"
    local output_file="/tmp/test_output_$$"

    cleanup_test_dir "$test_dir"

    # Setup: Create SDK structure
    print_info "Setting up: Creating SDK with Python template"
    set +e
    run_script "$output_file" "$PROJECT_ROOT/scripts/agentize-init.sh" \
        AGENTIZE_PROJECT_NAME="test_proj" \
        AGENTIZE_PROJECT_PATH="$test_dir" \
        AGENTIZE_PROJECT_LANG="python"
    local setup_exit=$?
    set -e

    if [ $setup_exit -ne 0 ]; then
        print_fail "Setup failed: Could not create initial SDK structure"
        cat "$output_file"
        cleanup_test_dir "$test_dir"
        rm -f "$output_file"
        return
    fi

    # Remove git-msg-tags.md
    print_info "Removing git-msg-tags.md to simulate missing file"
    rm -f "$test_dir/docs/git-msg-tags.md"

    # Test: Update should recreate the file
    print_info "Testing: Update mode recreates missing git-msg-tags.md"
    set +e
    run_script "$output_file" "$PROJECT_ROOT/scripts/agentize-update.sh" \
        AGENTIZE_PROJECT_PATH="$test_dir"
    local exit_code=$?
    set -e

    # Verify file was created
    if [ $exit_code -eq 0 ] && [ -f "$test_dir/docs/git-msg-tags.md" ]; then
        # Check for Python-specific content (deps tag) and absence of C/C++ build tag
        if grep -q '`deps`' "$test_dir/docs/git-msg-tags.md" && ! grep -q '`build`' "$test_dir/docs/git-msg-tags.md"; then
            print_pass "Update mode recreated git-msg-tags.md with Python-specific content"
        else
            print_fail "git-msg-tags.md was created but lacks Python-specific content"
            cat "$test_dir/docs/git-msg-tags.md"
        fi
    else
        print_fail "Update mode did not recreate missing git-msg-tags.md"
        cat "$output_file"
    fi

    cleanup_test_dir "$test_dir"
    rm -f "$output_file"
}

#####################################################################
# TC4: Update mode preserves existing git-msg-tags.md
#####################################################################
test_update_preserves_git_tags() {
    print_test_header "TC4: Update mode preserves existing git-msg-tags.md"

    local test_dir="/tmp/test_update_preserve_tags_$$"
    local output_file="/tmp/test_output_$$"

    cleanup_test_dir "$test_dir"

    # Setup: Create SDK structure
    print_info "Setting up: Creating SDK with C template"
    set +e
    run_script "$output_file" "$PROJECT_ROOT/scripts/agentize-init.sh" \
        AGENTIZE_PROJECT_NAME="test_proj" \
        AGENTIZE_PROJECT_PATH="$test_dir" \
        AGENTIZE_PROJECT_LANG="c"
    local setup_exit=$?
    set -e

    if [ $setup_exit -ne 0 ]; then
        print_fail "Setup failed: Could not create initial SDK structure"
        cat "$output_file"
        cleanup_test_dir "$test_dir"
        rm -f "$output_file"
        return
    fi

    # Modify git-msg-tags.md with custom content
    print_info "Adding custom content to git-msg-tags.md"
    echo "# Custom tags - DO NOT OVERWRITE" > "$test_dir/docs/git-msg-tags.md"
    echo "custom-tag: Custom modification description" >> "$test_dir/docs/git-msg-tags.md"

    # Test: Update should preserve custom content
    print_info "Testing: Update mode preserves existing git-msg-tags.md"
    set +e
    run_script "$output_file" "$PROJECT_ROOT/scripts/agentize-update.sh" \
        AGENTIZE_PROJECT_PATH="$test_dir"
    local exit_code=$?
    set -e

    # Verify custom content is preserved
    if [ $exit_code -eq 0 ] && grep -q "# Custom tags - DO NOT OVERWRITE" "$test_dir/docs/git-msg-tags.md"; then
        if grep -q "custom-tag:" "$test_dir/docs/git-msg-tags.md"; then
            print_pass "Update mode preserved custom git-msg-tags.md content"
        else
            print_fail "Custom content partially lost"
            cat "$test_dir/docs/git-msg-tags.md"
        fi
    else
        print_fail "Update mode did not preserve existing git-msg-tags.md"
        cat "$output_file"
        if [ -f "$test_dir/docs/git-msg-tags.md" ]; then
            cat "$test_dir/docs/git-msg-tags.md"
        fi
    fi

    cleanup_test_dir "$test_dir"
    rm -f "$output_file"
}

#####################################################################
# TC5: Init mode with invalid LANG (should fail)
#####################################################################
test_init_invalid_lang() {
    print_test_header "TC5: Init mode with invalid LANG (should fail)"

    local test_dir="/tmp/test_invalid_lang_$$"
    local output_file="/tmp/test_output_$$"

    cleanup_test_dir "$test_dir"

    # Run make with invalid language
    set +e
    run_script "$output_file" "$PROJECT_ROOT/scripts/agentize-init.sh" \
        AGENTIZE_PROJECT_NAME="test_proj" \
        AGENTIZE_PROJECT_PATH="$test_dir" \
        AGENTIZE_PROJECT_LANG="rust"
    local exit_code=$?
    set -e

    # Verify it failed with appropriate error message
    if [ $exit_code -ne 0 ]; then
        # Check error message mentions template not found
        if grep -qi "template.*not found\|invalid.*language" "$output_file" || \
           grep -q "rust" "$output_file"; then
            print_pass "Init mode correctly rejects invalid language 'rust'"
        else
            print_fail "Error message doesn't clearly indicate template/language issue"
            cat "$output_file"
        fi
    else
        print_fail "Init mode should fail with invalid language, but succeeded"
        cat "$output_file"
    fi

    cleanup_test_dir "$test_dir"
    rm -f "$output_file"
}

#####################################################################
# TC6: Update mode infers LANG from existing structure
#####################################################################
test_update_infers_lang() {
    print_test_header "TC6: Update mode infers LANG from existing structure"

    local test_dir="/tmp/test_infer_lang_$$"
    local output_file="/tmp/test_output_$$"

    cleanup_test_dir "$test_dir"

    # Setup: Create Python SDK
    print_info "Setting up: Creating Python SDK"
    set +e
    run_script "$output_file" "$PROJECT_ROOT/scripts/agentize-init.sh" \
        AGENTIZE_PROJECT_NAME="test_proj" \
        AGENTIZE_PROJECT_PATH="$test_dir" \
        AGENTIZE_PROJECT_LANG="python"
    local setup_exit=$?
    set -e

    if [ $setup_exit -ne 0 ]; then
        print_fail "Setup failed: Could not create initial SDK structure"
        cat "$output_file"
        cleanup_test_dir "$test_dir"
        rm -f "$output_file"
        return
    fi

    # Remove git-msg-tags.md to trigger recreation with language detection
    print_info "Removing git-msg-tags.md to trigger language detection"
    rm -f "$test_dir/docs/git-msg-tags.md"

    # Test: Update without LANG should infer Python from structure
    print_info "Testing: Update mode infers Python from project structure"
    set +e
    run_script "$output_file" "$PROJECT_ROOT/scripts/agentize-update.sh" \
        AGENTIZE_PROJECT_PATH="$test_dir"
    local exit_code=$?
    set -e

    # Verify Python template was used
    if [ $exit_code -eq 0 ] && [ -f "$test_dir/docs/git-msg-tags.md" ]; then
        # Python template should have `deps` but not `build`
        if grep -q '`deps`' "$test_dir/docs/git-msg-tags.md" && ! grep -q '`build`' "$test_dir/docs/git-msg-tags.md"; then
            print_pass "Update mode correctly inferred Python and used Python template"
        else
            print_fail "Wrong template used (expected Python template with deps, no build)"
            cat "$test_dir/docs/git-msg-tags.md"
        fi
    else
        print_fail "Update mode did not recreate git-msg-tags.md with language inference"
        cat "$output_file"
    fi

    cleanup_test_dir "$test_dir"
    rm -f "$output_file"
}

#####################################################################
# Main test execution
#####################################################################
main() {
    echo "======================================================="
    echo "Makefile Validation Logic Test Suite"
    echo "======================================================="
    echo ""
    echo "Testing mode-specific parameter requirements and"
    echo "git-msg-tags.md handling in agentize target"
    echo ""

    # Run all test cases
    test_init_without_lang
    test_update_without_lang
    test_update_creates_git_tags
    test_update_preserves_git_tags
    test_init_invalid_lang
    test_update_infers_lang

    # Print summary
    echo ""
    echo "======================================================="
    echo "Test Summary"
    echo "======================================================="
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Run main function
main
