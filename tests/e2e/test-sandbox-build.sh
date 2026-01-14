#!/bin/bash

set -e

echo "=== Testing sandbox Dockerfile ==="

# Build the Docker image
echo "Building Docker image..."
docker build -t agentize-sandbox-test ./sandbox

# Verify Node.js
echo "Verifying Node.js..."
docker run --rm agentize-sandbox-test node --version

# Verify npm
echo "Verifying npm..."
docker run --rm agentize-sandbox-test npm --version

# Verify Python + uv
echo "Verifying Python and uv..."
docker run --rm agentize-sandbox-test python3 --version
docker run --rm agentize-sandbox-test uv --version

# Verify Git
echo "Verifying Git..."
docker run --rm agentize-sandbox-test git --version

# Verify Chrome
echo "Verifying Chrome..."
docker run --rm agentize-sandbox-test google-chrome --version

# Verify claude-code-router
echo "Verifying claude-code-router..."
docker run --rm agentize-sandbox-test claude-code-router --version

echo "=== All sandbox tests passed ==="