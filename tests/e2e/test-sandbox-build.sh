#!/bin/bash

set -e

echo "=== Testing sandbox Dockerfile ==="

# Skip if sandbox prerequisites are missing
if ! command -v uv >/dev/null 2>&1; then
    echo "SKIP: sandbox tests require 'uv'"
    exit 0
fi
if ! command -v podman >/dev/null 2>&1; then
    echo "SKIP: sandbox tests require 'podman'"
    exit 0
fi
if ! podman info >/dev/null 2>&1; then
    echo "SKIP: podman is not available (daemon not running)"
    exit 0
fi

# Build the Docker image using the Python script's build command
echo "Building Docker image..."
uv ./sandbox/run.py --build

# Verify Node.js (use /bin/sh -c to bypass entrypoint)
echo "Verifying Node.js..."
podman run --rm --entrypoint=/bin/sh agentize-sandbox -c "node --version"

# Verify npm
echo "Verifying npm..."
podman run --rm --entrypoint=/bin/sh agentize-sandbox -c "npm --version"

# Verify Python + uv
echo "Verifying Python and uv..."
podman run --rm --entrypoint=/bin/sh agentize-sandbox -c "uv --version"
podman run --rm --entrypoint=/bin/sh agentize-sandbox -c "uv --version"

# Verify Git
echo "Verifying Git..."
podman run --rm --entrypoint=/bin/sh agentize-sandbox -c "git --version"

# Verify Chrome/Chromium
echo "Verifying Chrome/Chromium..."
podman run --rm --entrypoint=/bin/sh agentize-sandbox -c "chromium-browser --version" || podman run --rm --entrypoint=/bin/sh agentize-sandbox -c "google-chrome --version"

# Verify claude-code-router
echo "Verifying claude-code-router..."
podman run --rm --entrypoint=/bin/sh agentize-sandbox -c "claude-code-router --version"

# Verify GitHub CLI is installed
echo "Verifying GitHub CLI..."
podman run --rm --entrypoint=/bin/sh agentize-sandbox -c "test -f /usr/local/bin/gh && echo 'gh exists'"

# Verify entrypoint script exists
echo "Verifying entrypoint script..."
podman run --rm --entrypoint=/bin/sh agentize-sandbox -c "test -f /usr/local/bin/entrypoint"

echo "=== All sandbox tests passed ==="
