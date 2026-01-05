#!/usr/bin/env bash
# Test: handsoff-auto-continue.sh hook behavior

source "$(dirname "$0")/../common.sh"

test_info "Testing handsoff-auto-continue hook with bounded counter"

HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/handsoff-auto-continue.sh"
STATE_DIR="$PROJECT_ROOT/.tmp/claude-hooks/handsoff-sessions"
COUNTER_FILE="$STATE_DIR/continuation-count"

# Clean up state before tests
cleanup_state() {
    rm -rf "$STATE_DIR"
}

# Test 1: Bounded allow/ask sequence with HANDSOFF_MAX_CONTINUATIONS=2
test_info "Test 1: Bounded allow/ask sequence (max=2)"
cleanup_state

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=2

# First call: should return allow (count=1)
result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "allow" ]]; then
    test_fail "First call: Expected 'allow', got '$result'"
fi

# Second call: should return allow (count=2)
result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "allow" ]]; then
    test_fail "Second call: Expected 'allow', got '$result'"
fi

# Third call: should return ask (count=3, at limit)
result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" != "ask" ]]; then
    test_fail "Third call: Expected 'ask', got '$result'"
fi

test_pass "Bounded sequence works correctly (2 allows, then ask)"

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS
cleanup_state

# Test 2: Fail-closed when CLAUDE_HANDSOFF is unset
test_info "Test 2: Fail-closed when CLAUDE_HANDSOFF unset"

result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" == "ask" ]]; then
    test_pass "Returns 'ask' when CLAUDE_HANDSOFF unset (fail-closed)"
else
    test_fail "Expected 'ask', got '$result'"
fi

# Verify no counter file created
if [[ -f "$COUNTER_FILE" ]]; then
    test_fail "Counter file should not be created when hands-off disabled"
else
    test_pass "No counter file created when hands-off disabled"
fi

# Test 3: Fail-closed on invalid max value
test_info "Test 3: Fail-closed on invalid HANDSOFF_MAX_CONTINUATIONS"
cleanup_state

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS="invalid"

result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" == "ask" ]]; then
    test_pass "Returns 'ask' on invalid max value (fail-closed)"
else
    test_fail "Expected 'ask', got '$result'"
fi

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS

# Test 4: Fail-closed on non-positive max value
test_info "Test 4: Fail-closed on non-positive HANDSOFF_MAX_CONTINUATIONS"
cleanup_state

export CLAUDE_HANDSOFF=true
export HANDSOFF_MAX_CONTINUATIONS=0

result=$("$HOOK_SCRIPT" "Stop" "Agent completed milestone" '{}')
if [[ "$result" == "ask" ]]; then
    test_pass "Returns 'ask' on zero max value (fail-closed)"
else
    test_fail "Expected 'ask', got '$result'"
fi

unset CLAUDE_HANDSOFF
unset HANDSOFF_MAX_CONTINUATIONS

# Clean up after all tests
cleanup_state
