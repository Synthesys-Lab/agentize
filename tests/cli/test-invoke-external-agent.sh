#!/usr/bin/env bash
# Test suite for scripts/invoke-external-agent.sh
# Tests the unified external agent wrapper

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRAPPER_SCRIPT="$PROJECT_ROOT/scripts/invoke-external-agent.sh"
TEMP_DIR=".tmp/test-invoke-external-agent-$$"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

echo "Starting test suite for invoke-external-agent.sh..."
echo ""

# Test 1: Wrapper exists
echo -n "Test 1: Wrapper script exists ... "
if [ -f "$WRAPPER_SCRIPT" ]; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 2: Wrapper is executable
echo -n "Test 2: Wrapper script is executable ... "
if [ -x "$WRAPPER_SCRIPT" ]; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 3: Missing arguments error
echo -n "Test 3: Missing arguments shows error message ... "
OUTPUT=$("$WRAPPER_SCRIPT" 2>&1 || true)
if echo "$OUTPUT" | grep -q "Usage:"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 4: Missing input file error
echo -n "Test 4: Missing input file shows error message ... "
mkdir -p "$TEMP_DIR"
OUTPUT=$("$WRAPPER_SCRIPT" auto /nonexistent/file.txt "$TEMP_DIR/output.txt" 2>&1 || true)
if echo "$OUTPUT" | grep -q "not found"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 5: Invalid AGENTIZE_EXTERNAL_AGENT error
echo -n "Test 5: Invalid AGENTIZE_EXTERNAL_AGENT shows error ... "
echo "test" > "$TEMP_DIR/input.txt"
OUTPUT=$(AGENTIZE_EXTERNAL_AGENT=invalid "$WRAPPER_SCRIPT" auto "$TEMP_DIR/input.txt" "$TEMP_DIR/output.txt" 2>&1 || true)
if echo "$OUTPUT" | grep -q "Invalid AGENTIZE_EXTERNAL_AGENT"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 6: Valid env var (auto)
echo -n "Test 6: AGENTIZE_EXTERNAL_AGENT=auto is accepted ... "
OUTPUT=$(AGENTIZE_EXTERNAL_AGENT=auto "$WRAPPER_SCRIPT" auto "$TEMP_DIR/input.txt" "$TEMP_DIR/output.txt" 2>&1 || true)
if ! echo "$OUTPUT" | grep -q "Invalid"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 7: Valid env var (codex)
echo -n "Test 7: AGENTIZE_EXTERNAL_AGENT=codex is accepted ... "
OUTPUT=$(AGENTIZE_EXTERNAL_AGENT=codex "$WRAPPER_SCRIPT" auto "$TEMP_DIR/input.txt" "$TEMP_DIR/output.txt" 2>&1 || true)
if ! echo "$OUTPUT" | grep -q "Invalid"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 8: Valid env var (agent)
echo -n "Test 8: AGENTIZE_EXTERNAL_AGENT=agent is accepted ... "
OUTPUT=$(AGENTIZE_EXTERNAL_AGENT=agent "$WRAPPER_SCRIPT" auto "$TEMP_DIR/input.txt" "$TEMP_DIR/output.txt" 2>&1 || true)
if ! echo "$OUTPUT" | grep -q "Invalid"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 9: Valid env var (claude)
echo -n "Test 9: AGENTIZE_EXTERNAL_AGENT=claude is accepted ... "
OUTPUT=$(AGENTIZE_EXTERNAL_AGENT=claude "$WRAPPER_SCRIPT" auto "$TEMP_DIR/input.txt" "$TEMP_DIR/output.txt" 2>&1 || true)
if ! echo "$OUTPUT" | grep -q "Invalid"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 10: Output directory creation
echo -n "Test 10: Output directory is created ... "
mkdir -p "$TEMP_DIR/nested"
echo "test" > "$TEMP_DIR/nested/input.txt"
"$WRAPPER_SCRIPT" auto "$TEMP_DIR/nested/input.txt" "$TEMP_DIR/nested/deep/output.txt" 2>&1 || true
if [ -d "$TEMP_DIR/nested/deep" ]; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

echo ""
echo "Test Results:"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
