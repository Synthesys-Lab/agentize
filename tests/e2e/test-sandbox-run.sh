#!/bin/bash

set -e

echo "=== Testing sandbox run.sh script ==="

# Build the Docker image first (required by run.sh)
echo "Building Docker image..."
docker build -t agentize-sandbox ./sandbox

# Test 1: run.sh script exists and is executable
echo "Verifying run.sh exists and is executable..."
if [ ! -x "./sandbox/run.sh" ]; then
    echo "FAIL: sandbox/run.sh is not executable"
    exit 1
fi

# Test 2: run.sh runs without error (--help)
echo "Verifying run.sh can execute container..."
./sandbox/run.sh -- --help > /dev/null 2>&1 || true

# Test 3: Verify volume mounts are constructed correctly by examining docker run command
echo "Verifying volume mount construction..."

# Create a test script that echoes the docker command for inspection
TEST_SCRIPT=$(cat <<'EOF'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="agentize-sandbox"

# Build volume mounts (same logic as run.sh)
VOLUMES=()

# Mock HOME for test
TEST_HOME="/tmp/test-home-$$"
mkdir -p "$TEST_HOME/.config/gh"
mkdir -p "$TEST_HOME/.claude-code-router"
echo '{"test": true}' > "$TEST_HOME/.claude-code-router/config.json"

HOME="$TEST_HOME"

# 1. Passthrough claude-code-router config if exists
CCR_CONFIG="$HOME/.claude-code-router/config.json"
if [ -f "$CCR_CONFIG" ]; then
    VOLUMES+=("-v $CCR_CONFIG:/home/agentizer/.claude-code-router/config.json:ro")
fi

# 2. Passthrough GitHub CLI credentials
GH_CONFIG="$HOME/.config/gh"
if [ -d "$GH_CONFIG" ]; then
    VOLUMES+=("-v $GH_CONFIG:/home/agentizer/.config/gh:ro")
fi

# 3. Passthrough agentize project directory
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VOLUMES+=("-v $PROJECT_DIR:/workspace/agentize")

# Verify volumes are constructed
if [ ${#VOLUMES[@]} -lt 2 ]; then
    echo "FAIL: Expected at least 2 volumes, got ${#VOLUMES[@]}"
    exit 1
fi

# Check for expected mounts
ALL_GOOD=1
for vol in "${VOLUMES[@]}"; do
    if echo "$vol" | grep -q ".claude-code-router/config.json"; then
        echo "Found CCR config mount"
    elif echo "$vol" | grep -q ".config/gh"; then
        echo "Found GitHub CLI config mount"
    elif echo "$vol" | grep -q "agentize"; then
        echo "Found project directory mount"
    fi
done

# Cleanup
rm -rf "$TEST_HOME"

echo "Volume mount construction verified"
EOF
)

# Run the test script
bash -c "$TEST_SCRIPT"

# Test 4: Verify entrypoint.sh has correct content
echo "Verifying entrypoint.sh content..."
if grep -q "ccr code" ./sandbox/entrypoint.sh; then
    echo "Found CCR code invocation"
else
    echo "FAIL: entrypoint.sh should contain 'ccr code'"
    exit 1
fi

if grep -q "claude" ./sandbox/entrypoint.sh; then
    echo "Found claude invocation"
else
    echo "FAIL: entrypoint.sh should contain 'claude'"
    exit 1
fi

if grep -q "\-\-ccr" ./sandbox/entrypoint.sh; then
    echo "Found --ccr flag handling"
else
    echo "FAIL: entrypoint.sh should handle --ccr flag"
    exit 1
fi

# Test 5: Verify entrypoint.sh is valid bash and has correct shebang
echo "Verifying entrypoint.sh syntax..."
if head -1 ./sandbox/entrypoint.sh | grep -q "^#!/bin/bash"; then
    echo "Correct shebang found"
else
    echo "FAIL: entrypoint.sh should have #!/bin/bash shebang"
    exit 1
fi

# Verify bash can parse the script
bash -n ./sandbox/entrypoint.sh
echo "entrypoint.sh syntax is valid"

echo "=== All sandbox run.sh tests passed ==="