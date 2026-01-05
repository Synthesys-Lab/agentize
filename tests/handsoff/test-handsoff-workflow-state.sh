#!/usr/bin/env bash
# Test: Workflow state transitions for hands-off auto-continue

source "$(dirname "$0")/../common.sh"

test_info "Testing workflow state initialization and transitions"

# Use current directory (worktree) instead of AGENTIZE_HOME
WORKTREE_ROOT="$(git rev-parse --show-toplevel)"
STATE_DIR="$WORKTREE_ROOT/.tmp/claude-hooks/handsoff-sessions"
USERPROMPTSUBMIT_HOOK="$WORKTREE_ROOT/.claude/hooks/handsoff-userpromptsubmit.sh"
POSTTOOLUSE_HOOK="$WORKTREE_ROOT/.claude/hooks/handsoff-posttooluse.sh"
STOP_HOOK="$WORKTREE_ROOT/.claude/hooks/handsoff-auto-continue.sh"

TEST_SESSION_ID="test-wf-session-$(date +%s)"
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

# Test 1: UserPromptSubmit creates state for ultra-planner workflow
test_info "Test 1: UserPromptSubmit creates state for ultra-planner"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10

# Simulate user prompt with /ultra-planner
PROMPT_JSON='{"prompt": "/ultra-planner implement feature X"}'
"$USERPROMPTSUBMIT_HOOK" "UserPromptSubmit" "User submitted prompt" "$PROMPT_JSON" >/dev/null 2>&1

# Check state file was created
if [[ ! -f "$STATE_FILE" ]]; then
    test_fail "Test 1 - State file not created for ultra-planner workflow"
fi

# Verify state content
state_content=$(cat "$STATE_FILE")
if [[ "$state_content" != "ultra-planner:planning:0:10" ]]; then
    test_fail "Test 1 - Expected 'ultra-planner:planning:0:10', got '$state_content'"
fi

echo -e "${GREEN}✓ Test 1 passed: ultra-planner state initialized correctly${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
cleanup_state

# Test 2: UserPromptSubmit creates state for issue-to-impl workflow
test_info "Test 2: UserPromptSubmit creates state for issue-to-impl"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10

# Simulate user prompt with /issue-to-impl
PROMPT_JSON='{"prompt": "/issue-to-impl 42"}'
"$USERPROMPTSUBMIT_HOOK" "UserPromptSubmit" "User submitted prompt" "$PROMPT_JSON" >/dev/null 2>&1

# Check state file was created
if [[ ! -f "$STATE_FILE" ]]; then
    test_fail "Test 2 - State file not created for issue-to-impl workflow"
fi

# Verify state content
state_content=$(cat "$STATE_FILE")
if [[ "$state_content" != "issue-to-impl:docs_tests:0:10" ]]; then
    test_fail "Test 2 - Expected 'issue-to-impl:docs_tests:0:10', got '$state_content'"
fi

echo -e "${GREEN}✓ Test 2 passed: issue-to-impl state initialized correctly${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
cleanup_state

# Test 3: PostToolUse updates ultra-planner state on open-issue (placeholder)
test_info "Test 3: PostToolUse transitions ultra-planner on placeholder issue"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true

# Create initial state
echo "ultra-planner:planning:0:10" > "$STATE_FILE"

# Simulate open-issue tool call (auto mode for placeholder)
TOOL_JSON='{"tool": "Skill", "args": {"skill": "open-issue", "args": "--auto"}}'
"$POSTTOOLUSE_HOOK" "PostToolUse" "Tool executed" "$TOOL_JSON" >/dev/null 2>&1

# Verify state transition
state_content=$(cat "$STATE_FILE")
if [[ "$state_content" != "ultra-planner:awaiting_details:0:10" ]]; then
    test_fail "Test 3 - Expected 'ultra-planner:awaiting_details:0:10', got '$state_content'"
fi

echo -e "${GREEN}✓ Test 3 passed: ultra-planner transitioned to awaiting_details${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
cleanup_state

# Test 4: PostToolUse updates ultra-planner to done on issue update
test_info "Test 4: PostToolUse transitions ultra-planner to done on update"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true

# Create state in awaiting_details
echo "ultra-planner:awaiting_details:1:10" > "$STATE_FILE"

# Simulate open-issue tool call (update mode with --update flag)
TOOL_JSON='{"tool": "Skill", "args": {"skill": "open-issue", "args": "--update 42"}}'
"$POSTTOOLUSE_HOOK" "PostToolUse" "Tool executed" "$TOOL_JSON" >/dev/null 2>&1

# Verify state transition to done
state_content=$(cat "$STATE_FILE")
if [[ "$state_content" != "ultra-planner:done:1:10" ]]; then
    test_fail "Test 4 - Expected 'ultra-planner:done:1:10', got '$state_content'"
fi

echo -e "${GREEN}✓ Test 4 passed: ultra-planner transitioned to done${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
cleanup_state

# Test 4b: PostToolUse does NOT transition on new issue creation (sub-issues)
test_info "Test 4b: PostToolUse ignores new issue creation (no --update flag)"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true

# Create state in awaiting_details
echo "ultra-planner:awaiting_details:1:10" > "$STATE_FILE"

# Simulate open-issue tool call WITHOUT --update (creating new sub-issue)
TOOL_JSON='{"tool": "Skill", "args": {"skill": "open-issue", "args": ""}}'
"$POSTTOOLUSE_HOOK" "PostToolUse" "Tool executed" "$TOOL_JSON" >/dev/null 2>&1

# Verify state did NOT transition (should still be awaiting_details)
state_content=$(cat "$STATE_FILE")
if [[ "$state_content" != "ultra-planner:awaiting_details:1:10" ]]; then
    test_fail "Test 4b - Expected state to remain 'ultra-planner:awaiting_details:1:10', got '$state_content'"
fi

echo -e "${GREEN}✓ Test 4b passed: New issue creation does not trigger transition${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
cleanup_state

# Test 5: PostToolUse updates issue-to-impl on milestone
test_info "Test 5: PostToolUse transitions issue-to-impl on milestone"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true

# Create initial state
echo "issue-to-impl:docs_tests:0:10" > "$STATE_FILE"

# Simulate milestone tool call
TOOL_JSON='{"tool": "Skill", "args": {"skill": "milestone"}}'
"$POSTTOOLUSE_HOOK" "PostToolUse" "Tool executed" "$TOOL_JSON" >/dev/null 2>&1

# Verify state transition
state_content=$(cat "$STATE_FILE")
if [[ "$state_content" != "issue-to-impl:implementation:0:10" ]]; then
    test_fail "Test 5 - Expected 'issue-to-impl:implementation:0:10', got '$state_content'"
fi

echo -e "${GREEN}✓ Test 5 passed: issue-to-impl transitioned to implementation${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
cleanup_state

# Test 6: PostToolUse updates issue-to-impl to done on open-pr
test_info "Test 6: PostToolUse transitions issue-to-impl to done on PR"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true

# Create state in implementation
echo "issue-to-impl:implementation:2:10" > "$STATE_FILE"

# Simulate open-pr tool call
TOOL_JSON='{"tool": "Skill", "args": {"skill": "open-pr"}}'
"$POSTTOOLUSE_HOOK" "PostToolUse" "Tool executed" "$TOOL_JSON" >/dev/null 2>&1

# Verify state transition to done
state_content=$(cat "$STATE_FILE")
if [[ "$state_content" != "issue-to-impl:done:2:10" ]]; then
    test_fail "Test 6 - Expected 'issue-to-impl:done:2:10', got '$state_content'"
fi

echo -e "${GREEN}✓ Test 6 passed: issue-to-impl transitioned to done${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
cleanup_state

# Test 7: Stop returns ask when workflow is done
test_info "Test 7: Stop returns 'ask' when workflow done"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true

# Create state with done status
echo "issue-to-impl:done:3:10" > "$STATE_FILE"

result=$("$STOP_HOOK" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "ask" ]]; then
    test_fail "Test 7 - Expected 'ask' when workflow done, got '$result'"
fi

echo -e "${GREEN}✓ Test 7 passed: Stop returns 'ask' for done workflow${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
cleanup_state

# Clean up after all tests
cleanup_state
unset CLAUDE_SESSION_ID

# Final summary
echo ""
echo -e "${GREEN}All tests passed! (${TESTS_PASSED}/8)${NC}"
exit 0
