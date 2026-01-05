#!/usr/bin/env bash
# Test: handsoff-auto-continue.sh hook behavior

source "$(dirname "$0")/../common.sh"

test_info "Testing handsoff-auto-continue hook with bounded counter"

# Use current directory (worktree) instead of AGENTIZE_HOME
WORKTREE_ROOT="$(git rev-parse --show-toplevel)"
HOOK_SCRIPT="$WORKTREE_ROOT/.claude/hooks/handsoff-auto-continue.sh"
STATE_DIR="$WORKTREE_ROOT/.tmp/claude-hooks/handsoff-sessions"
TEST_SESSION_ID="test-session-$(date +%s)"
STATE_FILE="$STATE_DIR/${TEST_SESSION_ID}.state"

# Export session ID for hooks to use
export CLAUDE_SESSION_ID="$TEST_SESSION_ID"

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
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=2

# Create initial state file (simulating UserPromptSubmit hook)
echo "issue-to-impl:implementation:0:2" > "$STATE_FILE"

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

# Verify no state file created
if [[ -f "$STATE_FILE" ]]; then
    test_fail "Test 2 - State file should not be created when hands-off disabled"
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

# Test 5: Workflow done state blocks auto-continue
test_info "Test 5: Workflow 'done' state returns 'ask'"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10

# Create state file with 'done' status (simulating workflow completion)
echo "issue-to-impl:done:2:10" > "$STATE_FILE"

result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "ask" ]]; then
    test_fail "Test 5 - Expected 'ask' when workflow is done, got '$result'"
fi

echo -e "${GREEN}✓ Test 5 passed: Returns 'ask' when workflow state is 'done'${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
cleanup_state

# Test 6: Invalid state file format fails closed
test_info "Test 6: Invalid state file format returns 'ask'"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10

# Create malformed state file
echo "invalid-format" > "$STATE_FILE"

result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "ask" ]]; then
    test_fail "Test 6 - Expected 'ask' on invalid state format, got '$result'"
fi

echo -e "${GREEN}✓ Test 6 passed: Returns 'ask' on invalid state file format${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS

# Clean up after all tests
cleanup_state
unset CLAUDE_SESSION_ID

# Final summary
echo ""
echo -e "${GREEN}All tests passed! (${TESTS_PASSED}/6)${NC}"
exit 0
