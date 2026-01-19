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
# Test 2: Missing output file argument
# =============================================================================
test_info "Test 2: Missing output file → exit code 2"
result=$("$WRAPPER_SCRIPT" "$TEST_INPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 2 ] || test_fail "Expected exit code 2 for missing output file arg, got $exit_code"

# =============================================================================
# Test 3: Input file not found
# =============================================================================
test_info "Test 3: Input file not found → exit code 2"
result=$("$WRAPPER_SCRIPT" "$TMP_DIR/nonexistent.txt" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 2 ] || test_fail "Expected exit code 2 for missing input file, got $exit_code"
echo "$result" | grep -q "Error: Input file not found" || test_fail "Expected 'Input file not found' error"

# =============================================================================
# Test 4: Invalid AGENTIZE_EXTERNAL_AGENT value
# =============================================================================
test_info "Test 4: Invalid AGENTIZE_EXTERNAL_AGENT → exit code 1"
result=$(AGENTIZE_EXTERNAL_AGENT=invalid "$WRAPPER_SCRIPT" "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 1 ] || test_fail "Expected exit code 1 for invalid agent, got $exit_code"
echo "$result" | grep -q "Error: Invalid AGENTIZE_EXTERNAL_AGENT: invalid" || test_fail "Expected invalid agent error message"

# =============================================================================
# Test 5: Forced codex when unavailable
# =============================================================================
test_info "Test 5: Force codex when unavailable → exit code 1"
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=codex "$WRAPPER_SCRIPT" "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 1 ] || test_fail "Expected exit code 1 when codex forced but unavailable, got $exit_code"
echo "$result" | grep -q "codex CLI not found" || test_fail "Expected 'codex CLI not found' error"

# =============================================================================
# Test 6: Forced agent when unavailable
# =============================================================================
test_info "Test 6: Force agent when unavailable → exit code 1"
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=agent "$WRAPPER_SCRIPT" "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 1 ] || test_fail "Expected exit code 1 when agent forced but unavailable, got $exit_code"
echo "$result" | grep -q "agent CLI not found" || test_fail "Expected 'agent CLI not found' error"

# =============================================================================
# Test 7: Forced claude when unavailable
# =============================================================================
test_info "Test 7: Force claude when unavailable → exit code 1"
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=claude "$WRAPPER_SCRIPT" "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 1 ] || test_fail "Expected exit code 1 when claude forced but unavailable, got $exit_code"
echo "$result" | grep -q "claude CLI not found" || test_fail "Expected 'claude CLI not found' error"

# =============================================================================
# Test 8: Auto mode with no agents available
# =============================================================================
test_info "Test 8: Auto mode with no agents → exit code 1"
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=auto "$WRAPPER_SCRIPT" "$TEST_INPUT" "$TEST_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
[ "$exit_code" -eq 1 ] || test_fail "Expected exit code 1 when no agents available in auto mode, got $exit_code"
echo "$result" | grep -q "No external agent available" || test_fail "Expected 'No external agent available' error"

# =============================================================================
# Test 9: Output directory creation
# =============================================================================
test_info "Test 9: Output directory is created if missing"
NESTED_OUTPUT="$TMP_DIR/nested/path/output.txt"
# Use claude agent (will fail due to missing CLI) to test directory creation
result=$(PATH="/usr/bin:/bin" AGENTIZE_EXTERNAL_AGENT=claude "$WRAPPER_SCRIPT" "$TEST_INPUT" "$NESTED_OUTPUT" 2>&1) && exit_code=$? || exit_code=$?
# Should fail due to missing claude, but directory should be created
[ -d "$TMP_DIR/nested/path" ] || test_fail "Expected output directory to be created"

# =============================================================================
# Test 10: Default model is opus when AGENTIZE_EXTERNAL_MODEL not set
# =============================================================================
test_info "Test 10: Default model is opus"
# Script uses AGENTIZE_EXTERNAL_MODEL with default opus - verify via source inspection
# This is a sanity check that the env var mechanism works
result=$(grep 'AGENTIZE_EXTERNAL_MODEL:-opus' "$WRAPPER_SCRIPT")
[ -n "$result" ] || test_fail "Expected default model to be opus in script"

cleanup_dir "$TMP_DIR"

test_pass "invoke-external-agent.sh wrapper tests completed"
