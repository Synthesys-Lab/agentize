#!/usr/bin/env bash
# Test: Hands-off state history logging (HANDSOFF_DEBUG)

source "$(dirname "$0")/../common.sh"

test_info "Testing hands-off state history logging"

# Use current directory (worktree) instead of AGENTIZE_HOME
WORKTREE_ROOT="$(git rev-parse --show-toplevel)"
STATE_DIR="$WORKTREE_ROOT/.tmp/claude-hooks/handsoff-sessions"
HISTORY_DIR="$STATE_DIR/history"
USERPROMPTSUBMIT_HOOK="$WORKTREE_ROOT/.claude/hooks/handsoff-userpromptsubmit.sh"
POSTTOOLUSE_HOOK="$WORKTREE_ROOT/.claude/hooks/handsoff-posttooluse.sh"
STOP_HOOK="$WORKTREE_ROOT/.claude/hooks/handsoff-auto-continue.sh"

TEST_SESSION_ID="test-history-session-$(date +%s)"
STATE_FILE="$STATE_DIR/${TEST_SESSION_ID}.state"
HISTORY_FILE="$HISTORY_DIR/${TEST_SESSION_ID}.jsonl"

# Export session ID for hooks to use
export CLAUDE_SESSION_ID="$TEST_SESSION_ID"

# Clean up state before tests
cleanup_state() {
    rm -rf "$STATE_DIR"
}

# Helper: check JSON field value in last history line
check_history_field() {
    local field=$1
    local expected=$2
    local last_line=$(tail -n1 "$HISTORY_FILE")
    local actual=$(echo "$last_line" | grep -o "\"$field\":\"[^\"]*\"" | cut -d'"' -f4)
    if [[ "$actual" != "$expected" ]]; then
        test_fail "Expected $field='$expected', got '$actual'"
    fi
}

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: HANDSOFF_DEBUG unset does not create history file
test_info "Test 1: No history file when HANDSOFF_DEBUG unset"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10
unset HANDSOFF_DEBUG

# Create initial state
echo "issue-to-impl:docs_tests:0:10" > "$STATE_FILE"

# Run Stop hook
"$STOP_HOOK" "Stop" "Agent completed milestone" '{}' >/dev/null 2>&1

# Verify no history file created
if [[ -f "$HISTORY_FILE" ]]; then
    test_fail "Test 1 - History file should not exist when HANDSOFF_DEBUG unset"
fi

echo -e "${GREEN}✓ Test 1 passed: No history when debug disabled${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
cleanup_state

# Test 2: HANDSOFF_DEBUG=false does not create history file
test_info "Test 2: No history file when HANDSOFF_DEBUG=false"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10
export HANDSOFF_DEBUG=false

# Create initial state
echo "issue-to-impl:docs_tests:0:10" > "$STATE_FILE"

# Run Stop hook
"$STOP_HOOK" "Stop" "Agent completed milestone" '{}' >/dev/null 2>&1

# Verify no history file created
if [[ -f "$HISTORY_FILE" ]]; then
    test_fail "Test 2 - History file should not exist when HANDSOFF_DEBUG=false"
fi

echo -e "${GREEN}✓ Test 2 passed: No history when debug explicitly disabled${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
unset HANDSOFF_DEBUG
cleanup_state

# Test 3: UserPromptSubmit creates history entry
test_info "Test 3: UserPromptSubmit creates history entry"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10
export HANDSOFF_DEBUG=true

# Simulate user prompt with /issue-to-impl
PROMPT_JSON='{"prompt": "/issue-to-impl 42"}'
"$USERPROMPTSUBMIT_HOOK" "UserPromptSubmit" "User submitted prompt" "$PROMPT_JSON" >/dev/null 2>&1

# Verify history file created
if [[ ! -f "$HISTORY_FILE" ]]; then
    test_fail "Test 3 - History file not created"
fi

# Check entry count (trim whitespace from wc output)
line_count=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
if [[ "$line_count" != "1" ]]; then
    test_fail "Test 3 - Expected 1 history entry, got $line_count"
fi

# Check fields
check_history_field "event" "UserPromptSubmit"
check_history_field "workflow" "issue-to-impl"
check_history_field "state" "docs_tests"
check_history_field "count" "0"
check_history_field "max" "10"

echo -e "${GREEN}✓ Test 3 passed: UserPromptSubmit logged correctly${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
unset HANDSOFF_DEBUG
cleanup_state

# Test 4: PostToolUse appends history entry with tool info
test_info "Test 4: PostToolUse logs transition with tool info"
cleanup_state
mkdir -p "$STATE_DIR"
mkdir -p "$HISTORY_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_DEBUG=true

# Create initial state
echo "issue-to-impl:docs_tests:0:10" > "$STATE_FILE"

# Simulate milestone tool call
TOOL_JSON='{"tool": "Skill", "args": {"skill": "milestone"}}'
"$POSTTOOLUSE_HOOK" "PostToolUse" "Tool executed" "$TOOL_JSON" >/dev/null 2>&1

# Verify history file created
if [[ ! -f "$HISTORY_FILE" ]]; then
    test_fail "Test 4 - History file not created"
fi

# Check fields
check_history_field "event" "PostToolUse"
check_history_field "tool_name" "milestone"
check_history_field "tool_args" ""
check_history_field "new_state" "implementation"
check_history_field "state" "implementation"

echo -e "${GREEN}✓ Test 4 passed: PostToolUse logged with tool info${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_DEBUG
cleanup_state

# Test 5: Stop appends history entry with decision and reason
test_info "Test 5: Stop logs decision with reason code"
cleanup_state
mkdir -p "$STATE_DIR"
mkdir -p "$HISTORY_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10
export HANDSOFF_DEBUG=true

# Create initial state
echo "issue-to-impl:implementation:0:10" > "$STATE_FILE"

# Run Stop hook
"$STOP_HOOK" "Stop" "Milestone 2 created" '{}' >/dev/null 2>&1

# Verify history file created
if [[ ! -f "$HISTORY_FILE" ]]; then
    test_fail "Test 5 - History file not created"
fi

# Check fields
check_history_field "event" "Stop"
check_history_field "decision" "allow"
check_history_field "reason" "under_limit"
check_history_field "workflow" "issue-to-impl"
check_history_field "state" "implementation"

echo -e "${GREEN}✓ Test 5 passed: Stop logged with decision and reason${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
unset HANDSOFF_DEBUG
cleanup_state

# Test 6: Stop logs different reason codes correctly
test_info "Test 6: Stop logs 'workflow_done' reason"
cleanup_state
mkdir -p "$STATE_DIR"
mkdir -p "$HISTORY_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10
export HANDSOFF_DEBUG=true

# Create state with done status
echo "issue-to-impl:done:2:10" > "$STATE_FILE"

# Run Stop hook
"$STOP_HOOK" "Stop" "Workflow completed" '{}' >/dev/null 2>&1

# Check fields
check_history_field "event" "Stop"
check_history_field "decision" "ask"
check_history_field "reason" "workflow_done"

echo -e "${GREEN}✓ Test 6 passed: Stop logged 'workflow_done' correctly${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
unset HANDSOFF_DEBUG
cleanup_state

# Test 7: Multiple events create multiple history entries
test_info "Test 7: Multiple events append to history"
cleanup_state
mkdir -p "$STATE_DIR"

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=10
export HANDSOFF_DEBUG=true

# UserPromptSubmit
PROMPT_JSON='{"prompt": "/issue-to-impl 42"}'
"$USERPROMPTSUBMIT_HOOK" "UserPromptSubmit" "User submitted prompt" "$PROMPT_JSON" >/dev/null 2>&1

# PostToolUse
TOOL_JSON='{"tool": "Skill", "args": {"skill": "milestone"}}'
"$POSTTOOLUSE_HOOK" "PostToolUse" "Tool executed" "$TOOL_JSON" >/dev/null 2>&1

# Stop
"$STOP_HOOK" "Stop" "Milestone created" '{}' >/dev/null 2>&1

# Verify 3 entries (trim whitespace from wc output)
line_count=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
if [[ "$line_count" != "3" ]]; then
    test_fail "Test 7 - Expected 3 history entries, got $line_count"
fi

# Check each event type appears
events=$(grep -o '"event":"[^"]*"' "$HISTORY_FILE" | cut -d'"' -f4 | tr '\n' ' ')
if [[ "$events" != "UserPromptSubmit PostToolUse Stop "* ]]; then
    test_fail "Test 7 - Expected event sequence 'UserPromptSubmit PostToolUse Stop', got '$events'"
fi

echo -e "${GREEN}✓ Test 7 passed: Multiple events logged in sequence${NC}"
TESTS_PASSED=$((TESTS_PASSED + 1))

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
unset HANDSOFF_DEBUG
cleanup_state

# Clean up after all tests
cleanup_state
unset CLAUDE_SESSION_ID

# Final summary
echo ""
echo -e "${GREEN}All tests passed! (${TESTS_PASSED}/7)${NC}"
exit 0
