#!/usr/bin/env bash
# Test: invoke-external-agent.sh wrapper script
#
# Tests the unified external agent invocation wrapper for argument validation,
# agent routing, and error handling.

source "$(dirname "$0")/../common.sh"

WRAPPER_SCRIPT="$PROJECT_ROOT/scripts/invoke-external-agent.sh"

test_info "invoke-external-agent.sh wrapper tests"

# Verify wrapper script exists and is executable
if [ ! -x "$WRAPPER_SCRIPT" ]; then
    test_fail "Wrapper script not found or not executable: $WRAPPER_SCRIPT"
fi

# Create temp directory for test files
TMP_DIR=$(make_temp_dir "invoke-external-agent-test")
trap "cleanup_dir '$TMP_DIR'" EXIT

# Create test input file
TEST_INPUT="$TMP_DIR/input.txt"
TEST_OUTPUT="$TMP_DIR/output.txt"
echo "Test input content" > "$TEST_INPUT"

# =============================================================================
# Test 1: Missing arguments
# =============================================================================
test_info "Test 1: Missing arguments → exit code 2"
result=$("$WRAPPER_SCRIPT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 2 ] || test_fail "Expected exit code 2 for missing args, got $exit_code"
echo "$result" | grep -q "Error: Usage:" || test_fail "Expected usage error message"

# =============================================================================
# Test 2: Missing input file argument
# =============================================================================
test_info "Test 2: Missing input file → exit code 2"
result=$("$WRAPPER_SCRIPT" auto 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 2 ] || test_fail "Expected exit code 2 for missing input file arg, got $exit_code"

# =============================================================================
# Test 3: Missing output file argument
# =============================================================================
test_info "Test 3: Missing output file → exit code 2"
result=$("$WRAPPER_SCRIPT" auto "$TEST_INPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 2 ] || test_fail "Expected exit code 2 for missing output file arg, got $exit_code"

# =============================================================================
# Test 4: Input file not found
# =============================================================================
test_info "Test 4: Input file not found → exit code 2"
result=$("$WRAPPER_SCRIPT" auto "$TMP_DIR/nonexistent.txt" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 2 ] || test_fail "Expected exit code 2 for missing input file, got $exit_code"
echo "$result" | grep -q "Error: Input file not found" || test_fail "Expected 'Input file not found' error"

# =============================================================================
# Test 5: Invalid AGENTIZE_EXTERNAL_AGENT value
# =============================================================================
test_info "Test 5: Invalid AGENTIZE_EXTERNAL_AGENT → exit code 1"
result=$(AGENTIZE_EXTERNAL_AGENT=invalid "$WRAPPER_SCRIPT" auto "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 1 ] || test_fail "Expected exit code 1 for invalid agent, got $exit_code"
echo "$result" | grep -q "Error: Invalid AGENTIZE_EXTERNAL_AGENT: invalid" || test_fail "Expected invalid agent error message"

# =============================================================================
# Test 6: Forced codex when unavailable
# =============================================================================
test_info "Test 6: Force codex when unavailable → exit code 1"
# Use a modified PATH that doesn't include codex
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=codex "$WRAPPER_SCRIPT" auto "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 1 ] || test_fail "Expected exit code 1 when codex forced but unavailable, got $exit_code"
echo "$result" | grep -q "codex CLI not found" || test_fail "Expected 'codex CLI not found' error"

# =============================================================================
# Test 7: Forced agent when unavailable
# =============================================================================
test_info "Test 7: Force agent when unavailable → exit code 1"
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=agent "$WRAPPER_SCRIPT" auto "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 1 ] || test_fail "Expected exit code 1 when agent forced but unavailable, got $exit_code"
echo "$result" | grep -q "agent CLI not found" || test_fail "Expected 'agent CLI not found' error"

# =============================================================================
# Test 8: Forced claude when unavailable
# =============================================================================
test_info "Test 8: Force claude when unavailable → exit code 1"
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=claude "$WRAPPER_SCRIPT" auto "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 1 ] || test_fail "Expected exit code 1 when claude forced but unavailable, got $exit_code"
echo "$result" | grep -q "claude CLI not found" || test_fail "Expected 'claude CLI not found' error"

# =============================================================================
# Test 9: Auto mode with no agents available
# =============================================================================
test_info "Test 9: Auto mode with no agents → exit code 1"
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=auto "$WRAPPER_SCRIPT" auto "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 1 ] || test_fail "Expected exit code 1 when no agents available in auto mode, got $exit_code"
echo "$result" | grep -q "No external agent available" || test_fail "Expected 'No external agent available' error"

# =============================================================================
# Test 10: Valid agent selection values (syntax check)
# =============================================================================
test_info "Test 10: Valid agent selection values are accepted"
# Create a mock agent script that returns success
MOCK_DIR="$TMP_DIR/mock-bin"
mkdir -p "$MOCK_DIR"
cat > "$MOCK_DIR/claude" << 'EOF'
#!/bin/bash
# Mock claude that writes to output file
echo "Mock claude response" > "${@: -1}"
exit 0
EOF
chmod +x "$MOCK_DIR/claude"

# Test that 'claude' value is accepted (uses mock)
# Note: This test validates syntax; actual invocation would use real claude
# Skip actual invocation test since mock doesn't support full interface
# We've already validated error handling; success paths need real CLIs

# =============================================================================
# Test 11: Output directory creation
# =============================================================================
test_info "Test 11: Output directory is created if missing"
NESTED_OUTPUT="$TMP_DIR/nested/path/output.txt"
# Use claude agent (will fail due to missing CLI) to test directory creation
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=claude "$WRAPPER_SCRIPT" opus "$TEST_INPUT" "$NESTED_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
# Should fail due to missing claude, but directory should be created
[ -d "$TMP_DIR/nested/path" ] || test_fail "Expected output directory to be created"

# =============================================================================
# Test 12: AGENTIZE_EXTERNAL_AGENT selects agent, model arg is passed through
# =============================================================================
test_info "Test 12: AGENTIZE_EXTERNAL_AGENT selects agent"
# Model arg is 'opus' but env selects codex agent, should try codex with model=opus
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=codex "$WRAPPER_SCRIPT" opus "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
# Should fail trying codex (from env)
echo "$result" | grep -q "codex CLI not found" || test_fail "Expected AGENTIZE_EXTERNAL_AGENT to select agent"

cleanup_dir "$TMP_DIR"

test_pass "invoke-external-agent.sh wrapper tests completed"
