#!/usr/bin/env bash
# Test: handsoff-auto-continue.sh hook behavior

source "$(dirname "$0")/../common.sh"

test_info "Testing handsoff-auto-continue hook with bounded counter"

# Use current directory (worktree) instead of AGENTIZE_HOME
WORKTREE_ROOT="$(git rev-parse --show-toplevel)"
HOOK_SCRIPT="$WORKTREE_ROOT/.claude/hooks/handsoff-auto-continue.sh"
STATE_DIR="$WORKTREE_ROOT/.tmp/claude-hooks/handsoff-sessions"
COUNTER_FILE="$STATE_DIR/continuation-count"

# Clean up state before tests
cleanup_state() {
    rm -rf "$STATE_DIR"
}

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Bounded allow/ask sequence with HANDSOFF_MAX_CONTINUATIONS=2
test_info "Test 1: Bounded allow/ask sequence (max=2)"
cleanup_state

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=2

# First call: should return allow (count=1)
result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "allow" ]]; then
    test_fail "Test 1.1 - First call: Expected 'allow', got '$result'"
fi

# Second call: should return allow (count=2)
result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "allow" ]]; then
    test_fail "Test 1.2 - Second call: Expected 'allow', got '$result'"
fi

# Third call: should return ask (count=3, at limit)
result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "ask" ]]; then
    test_fail "Test 1.3 - Third call: Expected 'ask', got '$result'"
fi

echo -e "${GREEN}✓ Test 1 passed: Bounded sequence works correctly${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
cleanup_state

# Test 2: Fail-closed when CLAUDE_HANDSOFF is unset
test_info "Test 2: Fail-closed when CLAUDE_HANDSOFF unset"

result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "ask" ]]; then
    test_fail "Test 2 - Expected 'ask', got '$result'"
fi

# Verify no counter file created
if [[ -f "$COUNTER_FILE" ]]; then
    test_fail "Test 2 - Counter file should not be created when hands-off disabled"
fi

echo -e "${GREEN}✓ Test 2 passed: Returns 'ask' when CLAUDE_HANDSOFF unset${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

# Test 3: Fail-closed on invalid max value
test_info "Test 3: Fail-closed on invalid HANDSOFF_MAX_CONTINUATIONS"
cleanup_state

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS="invalid"

result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "ask" ]]; then
    test_fail "Test 3 - Expected 'ask', got '$result'"
fi

echo -e "${GREEN}✓ Test 3 passed: Returns 'ask' on invalid max value${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS

# Test 4: Fail-closed on non-positive max value
test_info "Test 4: Fail-closed on non-positive HANDSOFF_MAX_CONTINUATIONS"
cleanup_state

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=0

result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "ask" ]]; then
    test_fail "Test 4 - Expected 'ask', got '$result'"
fi

echo -e "${GREEN}✓ Test 4 passed: Returns 'ask' on zero max value${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS

# Clean up after all tests
cleanup_state

# Final summary
echo ""
echo -e "${GREEN}All tests passed! (${TESTS_PASSED}/4)${NC}"
exit 0
