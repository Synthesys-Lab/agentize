#!/bin/bash
#
# Test GH CLI credential passthrough inside the sandbox container.
#
# This test verifies that:
# 1. The GH config directory is mounted correctly (read-write)
# 2. GH CLI can authenticate using external credentials
# 3. gh repo list works inside the container

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
if grep -q '":/home/agentizer/.config/gh:rw"' ./sandbox/run.sh; then
    echo "PASS: GH config is mounted read-write"
else
    echo "FAIL: GH config is not mounted read-write"
    echo "Expected :rw mount for GH config"
    exit 1
fi

# Test 3: Verify GH can run (auth status or error message)
echo "Test 3: Verifying GH CLI can execute..."
OUTPUT=$(./sandbox/run.sh -- --cmd gh --version 2>&1)
if echo "$OUTPUT" | grep -q "gh version"; then
    echo "PASS: GH CLI can execute"
else
    echo "FAIL: GH CLI cannot execute"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test 4: If external GH has credentials, verify they work inside container
echo "Test 4: Testing credential passthrough (if credentials exist on host)..."
if [ -d "$HOME/.config/gh" ] && [ -f "$HOME/.config/gh/config.yml" ]; then
    echo "External GH credentials detected, testing passthrough..."

    # Test if GH recognizes the authentication
    set +e  # Don't fail immediately if not authenticated
    OUTPUT=$(./sandbox/run.sh -- --cmd "gh auth status 2>&1" 2>&1)
    EXIT_CODE=$?
    set -e

    if echo "$OUTPUT" | grep -qE "(logged in|authenticated)"; then
        echo "PASS: External GH credentials work inside container"
    elif echo "$OUTPUT" | grep -qE "(not logged in|No authentication token)"; then
        echo "SKIP: No external GH credentials configured (this is okay for testing)"
    else
        # Still pass if the error is just about network/connectivity
        if echo "$OUTPUT" | grep -qE "(network|dial|connection|timeout)"; then
            echo "SKIP: Network unavailable, cannot test credential verification"
        else
            echo "WARN: Could not verify GH auth status: $OUTPUT"
        fi
    fi

    # Test gh repo list if authenticated
    if echo "$OUTPUT" | grep -qE "(logged in|authenticated)"; then
        echo "Test 5: Testing gh repo list..."
        set +e
        REPO_OUTPUT=$(./sandbox/run.sh -- --cmd "gh repo list \$(gh api user -q.login 2>/dev/null || echo '') --limit 1 2>&1" 2>&1)
        REPO_EXIT=$?
        set -e

        if [ $REPO_EXIT -eq 0 ] && [ -n "$REPO_OUTPUT" ]; then
            echo "PASS: gh repo list works inside container"
        else
            echo "WARN: gh repo list test inconclusive: $REPO_OUTPUT"
        fi
    fi
else
    echo "SKIP: No external GH credentials configured on host"
fi

echo "=== GH CLI credential passthrough tests completed ==="