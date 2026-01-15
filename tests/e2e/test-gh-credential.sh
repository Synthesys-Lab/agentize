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

# Build the Docker image first (required by run.sh)
echo "Building Docker image..."
docker build -t agentize-sandbox ./sandbox

# Test 1: Verify GH CLI is installed
echo "Test 1: Verifying GH CLI is installed..."
OUTPUT=$(./sandbox/run.sh -- --cmd which gh 2>&1)
if echo "$OUTPUT" | grep -q "gh"; then
    echo "PASS: GH CLI is installed"
else
    echo "FAIL: GH CLI not found"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test 2: Verify GH config directory is mounted read-write
echo "Test 2: Verifying GH config mount is read-write..."
# The run.sh should mount GH config as :rw (read-write)
if grep -q '/home/agentizer/.config/gh:rw' ./sandbox/run.sh; then
    echo "PASS: GH config is mounted read-write"
else
    echo "FAIL: GH config is not mounted read-write"
    echo "Expected :rw mount for GH config"
    exit 1
fi

# Test 3: Verify GITHUB_TOKEN passthrough is configured
echo "Test 3: Verifying GITHUB_TOKEN passthrough..."
if grep -q 'GITHUB_TOKEN' ./sandbox/run.sh; then
    echo "PASS: GITHUB_TOKEN passthrough configured"
else
    echo "FAIL: GITHUB_TOKEN passthrough not configured"
    exit 1
fi

# Test 4: Verify GH can run (auth status or error message)
echo "Test 4: Verifying GH CLI can execute..."
OUTPUT=$(./sandbox/run.sh -- --cmd gh --version 2>&1)
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
    # Note: run.sh --cmd passes arguments directly without shell interpretation
    AUTH_OUTPUT=$(./sandbox/run.sh -- --cmd bash -c gh\ auth\ status 2>&1)
    AUTH_EXIT=$?
    set -e

    if echo "$AUTH_OUTPUT" | grep -qE "(logged in|authenticated)"; then
        echo "PASS: GITHUB_TOKEN works inside container"

        # Test gh repo list
        echo "Test 6: Testing gh repo list..."
        set +e
        # Get username first
        USERNAME=$(gh api user -q.login)
        REPO_OUTPUT=$(./sandbox/run.sh -- --cmd bash -c "gh repo list $USERNAME --limit 1" 2>&1)
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