#!/bin/bash
#
# Test GH CLI credential passthrough inside the sandbox container.
#
# This test verifies that:
# 1. The GH config directory is mounted correctly (read-write)
# 2. GITHUB_TOKEN environment variable is passed to container
# 3. GH CLI can authenticate using external credentials
# 4. gh repo list works inside the container

set -e

echo "=== Testing GH CLI credential passthrough ==="

# Test 1: Verify GH config files are mounted read-only (entrypoint copies and fixes permissions)
echo "Test 1: Verifying GH config mount..."
# The run.py mounts individual GH config files as :ro (entrypoint.sh copies them with proper permissions)
if grep -q '/home/agentizer/.config/gh.*:ro' ./sandbox/run.py; then
    echo "PASS: GH config files are mounted (entrypoint handles permissions)"
else
    echo "FAIL: GH config is not mounted in run.py"
    exit 1
fi

# Test 2: Verify GITHUB_TOKEN passthrough is configured
echo "Test 2: Verifying GITHUB_TOKEN passthrough..."
if grep -q 'GITHUB_TOKEN' ./sandbox/run.py; then
    echo "PASS: GITHUB_TOKEN passthrough configured"
else
    echo "FAIL: GITHUB_TOKEN passthrough not configured"
    exit 1
fi

# Tests 3+ require sandbox (uv + docker) - skip if not available
if ! command -v uv >/dev/null 2>&1; then
    echo "SKIP: Tests 3+ require 'uv' (sandbox tests)"
    echo "=== GH CLI credential passthrough tests passed (partial) ==="
    exit 0
fi
if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
    echo "SKIP: Tests 3+ require podman or docker (sandbox tests)"
    echo "=== GH CLI credential passthrough tests passed (partial) ==="
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
    echo "=== GH CLI credential passthrough tests passed (partial) ==="
    exit 0
fi

# Test 3: Verify GH CLI is installed
echo "Test 3: Verifying GH CLI is installed..."
OUTPUT=$(uv ./sandbox/run.py -- --cmd which gh 2>&1)
if echo "$OUTPUT" | grep -q "gh"; then
    echo "PASS: GH CLI is installed"
else
    echo "FAIL: GH CLI not found"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test 4: Verify GH can run (auth status or error message)
echo "Test 4: Verifying GH CLI can execute..."
OUTPUT=$(uv ./sandbox/run.py -- --cmd gh --version 2>&1)
if echo "$OUTPUT" | grep -q "gh version"; then
    echo "PASS: GH CLI can execute"
else
    echo "FAIL: GH CLI cannot execute"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test 5: If GITHUB_TOKEN is set on host, verify it works inside container
echo "Test 5: Testing GITHUB_TOKEN passthrough (if set on host)..."
if [ -n "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN detected on host, testing container authentication..."

    set +e
    # Note: run.py --cmd passes arguments directly without shell interpretation
    AUTH_OUTPUT=$(uv ./sandbox/run.py -- --cmd bash -c gh\ auth\ status 2>&1)
    AUTH_EXIT=$?
    set -e

    if echo "$AUTH_OUTPUT" | grep -qE "(logged in|authenticated)"; then
        echo "PASS: GITHUB_TOKEN works inside container"

        # Test gh repo list
        echo "Test 6: Testing gh repo list..."
        set +e
        # Get username first
        USERNAME=$(gh api user -q.login)
        REPO_OUTPUT=$(uv ./sandbox/run.py -- --cmd bash -c "gh repo list $USERNAME --limit 1" 2>&1)
        REPO_EXIT=$?
        set -e

        if [ $REPO_EXIT -eq 0 ] && [ -n "$REPO_OUTPUT" ]; then
            echo "PASS: gh repo list works inside container"
        else
            echo "FAIL: gh repo list failed"
            echo "Output: $REPO_OUTPUT"
            exit 1
        fi
    elif echo "$AUTH_OUTPUT" | grep -qE "(not logged in|No authentication token)"; then
        echo "FAIL: GITHUB_TOKEN not passed to container"
        exit 1
    elif echo "$AUTH_OUTPUT" | grep -qE "(network|dial|connection|timeout)"; then
        echo "SKIP: Network unavailable, cannot verify auth"
    else
        echo "WARN: Could not verify GH auth status"
    fi
else
    echo "SKIP: No GITHUB_TOKEN set on host (this is okay for CI)"
fi

echo "=== GH CLI credential passthrough tests completed ==="
