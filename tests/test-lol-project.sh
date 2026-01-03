#!/usr/bin/env bash
# Test suite for lol project command

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test utilities if available
if [ -f "$SCRIPT_DIR/test-utils.sh" ]; then
    source "$SCRIPT_DIR/test-utils.sh"
fi

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# ANSI colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test helper functions
test_start() {
    echo "Testing: $1"
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo "  Expected: $2"
    echo "  Got: $3"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" = "$actual" ]; then
        test_pass "$message"
        return 0
    else
        test_fail "$message" "$expected" "$actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if echo "$haystack" | grep -q "$needle"; then
        test_pass "$message"
        return 0
    else
        test_fail "$message" "contains '$needle'" "'$haystack'"
        return 1
    fi
}

# Setup test environment
setup_test_env() {
    TEST_DIR=$(mktemp -d)
    export TEST_DIR

    # Copy lol-cli.sh to test directory for isolated testing
    cp "$PROJECT_ROOT/scripts/lol-cli.sh" "$TEST_DIR/"

    # Create a mock .agentize.yaml
    cat > "$TEST_DIR/.agentize.yaml" <<EOF
project:
  name: test-project
  lang: python
git:
  default_branch: main
EOF
}

# Cleanup test environment
cleanup_test_env() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Test 1: lol project --help shows usage
test_project_help() {
    test_start "lol project --help shows usage information"

    # This test will be implemented after the lol-cli.sh is updated
    # For now, we'll mark it as pending
    echo "  SKIP: Pending implementation"
}

# Test 2: lol project --associate updates metadata
test_project_associate() {
    test_start "lol project --associate updates .agentize.yaml"

    setup_test_env

    # Create a test script that mocks the associate behavior
    # This will be implemented after agentize-project.sh is created
    echo "  SKIP: Pending implementation of agentize-project.sh"

    cleanup_test_env
}

# Test 3: lol project --create with mocked GraphQL
test_project_create() {
    test_start "lol project --create uses mocked GraphQL responses"

    setup_test_env

    # This test will use fixtures from tests/fixtures/github-projects/
    echo "  SKIP: Pending implementation of agentize-project.sh and fixtures"

    cleanup_test_env
}

# Test 4: lol project --automation outputs template
test_project_automation() {
    test_start "lol project --automation outputs workflow template"

    setup_test_env

    # This test checks that the automation template is printed correctly
    echo "  SKIP: Pending implementation of agentize-project.sh"

    cleanup_test_env
}

# Test 5: Missing .agentize.yaml shows helpful error
test_missing_metadata() {
    test_start "lol project without .agentize.yaml shows helpful error"

    setup_test_env
    rm "$TEST_DIR/.agentize.yaml"

    # This test checks error handling when .agentize.yaml is missing
    echo "  SKIP: Pending implementation of agentize-project.sh"

    cleanup_test_env
}

# Test 6: Metadata preservation during update
test_metadata_preservation() {
    test_start "lol project --associate preserves existing metadata fields"

    setup_test_env

    # Create .agentize.yaml with existing fields
    cat > "$TEST_DIR/.agentize.yaml" <<EOF
project:
  name: test-project
  lang: python
  source: src
git:
  default_branch: main
  remote_url: https://github.com/test/repo
EOF

    # After implementation, this test should verify that:
    # - project.name, project.lang, project.source are preserved
    # - git.default_branch and git.remote_url are preserved
    # - project.org and project.id are added
    echo "  SKIP: Pending implementation of agentize-project.sh"

    cleanup_test_env
}

# Run all tests
echo "============================================"
echo "Running lol project test suite"
echo "============================================"
echo ""

test_project_help
test_project_associate
test_project_create
test_project_automation
test_missing_metadata
test_metadata_preservation

echo ""
echo "============================================"
echo "Test Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "============================================"

# Return non-zero if any tests failed
if [ $TESTS_PASSED -ne $TESTS_RUN ]; then
    exit 1
fi

exit 0
