#!/bin/bash

set -e

echo "=== Testing sandbox run.py --cmd option ==="

# Skip if sandbox prerequisites are missing
if ! command -v uv >/dev/null 2>&1; then
    echo "SKIP: sandbox tests require 'uv'"
    exit 0
fi
if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
    echo "SKIP: sandbox tests require podman or docker"
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
    exit 0
fi

# Test 1: Verify run.py exists
echo "Test 1: Verifying run.py exists..."
if [ ! -f "./sandbox/run.py" ]; then
    echo "FAIL: sandbox/run.py does not exist"
    exit 1
fi
echo "PASS: run.py exists"

# Test 2: Non-interactive command execution (auto-builds if needed)
echo "Test 2: Testing non-interactive command execution..."
OUTPUT=$(uv ./sandbox/run.py -- --cmd ls /workspace 2>&1)
if echo "$OUTPUT" | grep -q "agentize"; then
    echo "PASS: --cmd ls /workspace executed successfully"
else
    echo "FAIL: Non-interactive command failed"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test 3: Command with arguments
echo "Test 3: Testing command with arguments..."
OUTPUT=$(uv ./sandbox/run.py -- --cmd bash -c "echo hello && pwd" 2>&1)
if echo "$OUTPUT" | grep -q "hello" && echo "$OUTPUT" | grep -q "/workspace"; then
    echo "PASS: Command with arguments executed successfully"
else
    echo "FAIL: Command with arguments failed"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test 4: Which command
echo "Test 4: Testing 'which' command..."
OUTPUT=$(uv ./sandbox/run.py -- --cmd which gh 2>&1)
if echo "$OUTPUT" | grep -q "gh"; then
    echo "PASS: 'which gh' executed successfully"
else
    echo "FAIL: 'which gh' failed"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test 5: Normal mode still works (--help)
echo "Test 5: Testing normal mode (--help)..."
OUTPUT=$(uv ./sandbox/run.py -- --help 2>&1)
if echo "$OUTPUT" | grep -q "Usage:"; then
    echo "PASS: Normal mode still works"
else
    echo "FAIL: Normal mode broken"
    echo "Output: $OUTPUT"
    exit 1
fi

echo "=== All sandbox run.py --cmd option tests passed ==="
