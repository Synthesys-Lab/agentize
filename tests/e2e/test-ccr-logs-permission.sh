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
# Check for CCR_DIR variable definition with .claude-code-router AND mkdir with $CCR_DIR/logs
if grep -q 'CCR_DIR=.*\.claude-code-router' ./sandbox/entrypoint.sh && \
   grep -q 'mkdir.*\$CCR_DIR/logs' ./sandbox/entrypoint.sh; then
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

# Test 3: Verify CCR uses --plugin-dir for plugin support
echo "Test 3: Verifying CCR command uses --plugin-dir..."
if grep -qE 'exec ccr code.*--plugin-dir' ./sandbox/entrypoint.sh; then
    echo "PASS: CCR uses --plugin-dir for plugin support"
else
    echo "FAIL: CCR should use --plugin-dir for plugin support"
    exit 1
fi

# Tests 4-5 require sandbox (uv + docker) - skip if not available
if ! command -v uv >/dev/null 2>&1; then
    echo "SKIP: Tests 4-5 require 'uv' (sandbox tests)"
    echo "=== CCR logs directory permission tests passed (partial) ==="
    exit 0
fi
if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
    echo "SKIP: Tests 4-5 require podman or docker (sandbox tests)"
    echo "=== CCR logs directory permission tests passed (partial) ==="
    exit 0
fi
runtime_ok=0
if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    runtime_ok=1
fi
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    runtime_ok=1
fi
if [ "$runtime_ok" -ne 1 ]; then
    echo "SKIP: container runtime not available (podman/docker not running)"
    echo "=== CCR logs directory permission tests passed (partial) ==="
    exit 0
fi

# Test 4: Verify CCR can run with --ccr flag without permission error
echo "Test 4: Testing CCR --help runs without permission error..."
OUTPUT=$(uv ./sandbox/run.py -- --ccr --help 2>&1)
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

# Test 5: Verify CCR version works
echo "Test 5: Testing CCR version..."
OUTPUT=$(uv ./sandbox/run.py -- --ccr --version 2>&1)
if echo "$OUTPUT" | grep -qE "[0-9]+\.[0-9]+\.[0-9]+"; then
    echo "PASS: CCR version displayed"
else
    echo "FAIL: CCR version not displayed"
    echo "Output: $OUTPUT"
    exit 1
fi

echo "=== CCR logs directory permission tests passed ==="
