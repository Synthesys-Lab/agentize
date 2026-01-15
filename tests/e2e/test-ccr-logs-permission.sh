#!/bin/bash
#
# Test CCR logs directory permission fix.
#
# This test verifies that:
# 1. CCR can create logs directory when running with --ccr flag
# 2. The entrypoint creates logs directory before CCR starts

set -e

echo "=== Testing CCR logs directory permission fix ==="

# Test 1: Verify entrypoint.sh exists and creates logs directory
echo "Test 1: Verifying entrypoint.sh creates logs directory..."
if grep -q 'mkdir.*claude-code-router.*logs' ./sandbox/entrypoint.sh; then
    echo "PASS: entrypoint.sh has logs directory creation"
else
    echo "FAIL: entrypoint.sh does not create logs directory"
    exit 1
fi

# Test 2: Verify sudo is installed in Dockerfile
echo "Test 2: Verifying sudo is installed in Dockerfile..."
if grep -q 'sudo' ./sandbox/Dockerfile; then
    echo "PASS: sudo is included in Dockerfile"
else
    echo "FAIL: sudo is not installed in Dockerfile"
    exit 1
fi

# Test 3: Verify CCR can run with --ccr flag without permission error
echo "Test 3: Testing CCR --help runs without permission error..."
OUTPUT=$(python3 ./sandbox/run.py -- --ccr --help 2>&1)
if echo "$OUTPUT" | grep -q "Usage:"; then
    echo "PASS: CCR runs without permission error"
else
    if echo "$OUTPUT" | grep -qE "(permission denied|EACCES|mkdir)"; then
        echo "FAIL: CCR still has permission error"
        echo "Output: $OUTPUT"
        exit 1
    else
        echo "FAIL: CCR --help did not show usage"
        echo "Output: $OUTPUT"
        exit 1
    fi
fi

# Test 4: Verify CCR does NOT use --plugin-dir (not supported by ccr code)
echo "Test 4: Verifying CCR command doesn't use --plugin-dir..."
if grep -qE 'exec ccr code.*--plugin-dir' ./sandbox/entrypoint.sh; then
    echo "FAIL: ccr code doesn't support --plugin-dir (it's passed to Claude, not CCR)"
    exit 1
else
    echo "PASS: CCR correctly does not use --plugin-dir with ccr code"
fi

# Test 5: Verify CCR version works
echo "Test 5: Testing CCR version..."
OUTPUT=$(python3 ./sandbox/run.py -- --ccr --version 2>&1)
if echo "$OUTPUT" | grep -qE "[0-9]+\.[0-9]+\.[0-9]+"; then
    echo "PASS: CCR version displayed"
else
    echo "FAIL: CCR version not displayed"
    echo "Output: $OUTPUT"
    exit 1
fi

echo "=== CCR logs directory permission tests passed ==="