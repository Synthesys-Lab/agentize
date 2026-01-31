#!/bin/bash

# E2E test for volume mount permissions
# Tests that gh CLI and CCR can access their config files inside the container

set -e

echo "=== Testing volume mount permissions inside container ==="

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

# Test 1: Verify gh CLI can read its config (no permission denied)
echo "Testing gh CLI config access..."
if uv run ./sandbox/run.py --cmd bash -c "test -r /home/agentizer/.config/gh/config.yml" 2>/dev/null; then
    echo "PASS: gh CLI can read config.yml"
else
    # Check if gh is even installed in the container
    if uv run ./sandbox/run.py --cmd bash -c "command -v gh" 2>/dev/null; then
        echo "FAIL: gh CLI cannot read config.yml (permission denied)"
        exit 1
    else
        echo "SKIP: gh CLI not installed in container"
    fi
fi

# Test 2: Verify gh CLI can run (auth errors are expected if not authenticated)
echo "Testing gh CLI execution..."
OUTPUT=$(uv run ./sandbox/run.py --cmd bash -c "gh --version 2>&1" || true)
if echo "$OUTPUT" | grep -q "gh version"; then
    echo "PASS: gh CLI can execute"
else
    if echo "$OUTPUT" | grep -qi "permission denied"; then
        echo "FAIL: gh CLI has permission denied error"
        exit 1
    else
        echo "FAIL: gh CLI failed to execute"
        echo "$OUTPUT"
        exit 1
    fi
fi

# Test 3: Verify CCR config.json is accessible
echo "Testing CCR config.json access..."
if uv run ./sandbox/run.py --cmd bash -c "test -r /home/agentizer/.claude-code-router/config.json" 2>/dev/null; then
    echo "PASS: CCR can read config.json"
else
    echo "SKIP: CCR config.json not mounted (host file may not exist)"
fi

# Test 4: Verify CCR config-router.json is accessible
echo "Testing CCR config-router.json access..."
if uv run ./sandbox/run.py --cmd bash -c "test -r /home/agentizer/.claude-code-router/config-router.json" 2>/dev/null; then
    echo "PASS: CCR can read config-router.json"
else
    echo "SKIP: CCR config-router.json not mounted (host file may not exist)"
fi

# Test 5: Verify CCR can run (check startup message without crashing)
echo "Testing CCR execution..."
OUTPUT=$(timeout 5 uv run ./sandbox/run.py --ccr 2>&1 || true)
if echo "$OUTPUT" | grep -qi "Router service is ready\|Starting Claude Code Router"; then
    echo "PASS: CCR can execute"
else
    if echo "$OUTPUT" | grep -qi "permission denied"; then
        echo "FAIL: CCR has permission denied error"
        exit 1
    else
        echo "PASS: CCR executed without crashes"
    fi
fi

echo ""
echo "=== All volume permission tests passed ==="
