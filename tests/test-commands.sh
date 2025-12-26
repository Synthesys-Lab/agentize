#!/usr/bin/env bash
# Test suite for command metadata validation
# Tests that command files exist, have proper structure, and are documented

set -e

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Root directory of the project
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Helper function to print test status
print_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

echo "=== Command Metadata Tests ==="
echo ""

# Test: spawn-worktree.md exists
if [ -f "$PROJECT_ROOT/claude/commands/spawn-worktree.md" ]; then
    print_pass "spawn-worktree.md exists"
else
    print_fail "spawn-worktree.md does not exist"
fi

# Test: spawn-worktree.md has proper name field
if [ -f "$PROJECT_ROOT/claude/commands/spawn-worktree.md" ] && grep -q "^name: spawn-worktree" "$PROJECT_ROOT/claude/commands/spawn-worktree.md"; then
    print_pass "spawn-worktree.md has correct name field"
else
    print_fail "spawn-worktree.md missing or has incorrect name field"
fi

# Test: spawn-worktree is listed in README.md
if grep -q "spawn-worktree.md" "$PROJECT_ROOT/claude/commands/README.md"; then
    print_pass "spawn-worktree is listed in claude/commands/README.md"
else
    print_fail "spawn-worktree is not listed in claude/commands/README.md"
fi

# Print summary
echo ""
echo "========================================"
echo "Total tests passed: $TESTS_PASSED"
echo "Total tests failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
