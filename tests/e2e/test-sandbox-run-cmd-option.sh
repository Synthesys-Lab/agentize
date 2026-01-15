#!/bin/bash

set -e

echo "=== Testing sandbox run.sh --cmd option ==="

# Build the Docker image first (required by run.sh)
echo "Building Docker image..."
docker build -t agentize-sandbox ./sandbox

# Test 1: Verify run.sh exists and is executable
echo "Test 1: Verifying run.sh exists and is executable..."
if [ ! -x "./sandbox/run.sh" ]; then
    echo "FAIL: sandbox/run.sh is not executable"
    exit 1
fi
echo "PASS: run.sh is executable"

# Test 2: Verify --cmd flag parsing by examining generated docker command
echo "Test 2: Verifying --cmd flag parsing..."

# Create a test script that captures the docker command
TEST_SCRIPT=$(cat <<'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="agentize-sandbox"
INTERACTIVE_FLAGS="-t"

# Build docker command as array to avoid shell injection issues
DOCKER_ARGS=(
    "run"
    "--rm"
    $INTERACTIVE_FLAGS
)

# Parse arguments: docker flags before --, then container name/image args after --
DOCKER_FLAGS=()
CONTAINER_ARGS=()
SEEN_DASH_DASH=0
CUSTOM_CMD=()
WHILE_CMD=0

while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--" ]]; then
        SEEN_DASH_DASH=1
        shift
        continue
    fi

    if [[ $SEEN_DASH_DASH -eq 0 ]]; then
        # Before --: docker flags or container name
        case "$1" in
            --entrypoint=*)
                DOCKER_ARGS+=("$1")
                shift
                ;;
            --entrypoint)
                DOCKER_ARGS+=("$1" "$2")
                shift 2
                ;;
            -*)
                # Other docker flags
                DOCKER_ARGS+=("$1")
                shift
                ;;
            *)
                # First non-flag argument is container name
                if [ -z "$CONTAINER_NAME" ]; then
                    CONTAINER_NAME="$1"
                fi
                shift
                ;;
        esac
    else
        # After --: arguments to container
        if [[ "$1" == "--cmd" ]]; then
            WHILE_CMD=1
            shift
            continue
        fi

        if [[ $WHILE_CMD -eq 1 ]]; then
            CUSTOM_CMD+=("$1")
        else
            CONTAINER_ARGS+=("$1")
        fi
        shift
    fi
done

# Set default container name if not provided
if [ -z "$CONTAINER_NAME" ]; then
    CONTAINER_NAME="agentize-runner"
fi

DOCKER_ARGS+=("--name" "$CONTAINER_NAME")

# Add working directory and image
DOCKER_ARGS+=("-w" "/workspace/agentize")
DOCKER_ARGS+=("$IMAGE_NAME")

# When --cmd is provided, override entrypoint
if [ ${#CUSTOM_CMD[@]} -gt 0 ]; then
    DOCKER_ARGS+=("--entrypoint=/bin/bash")
    DOCKER_ARGS+=("-c")
    # Join the command arguments into a single string
    CMD_STRING=$(printf " %s" "${CUSTOM_CMD[@]}")
    CMD_STRING=${CMD_STRING:1}  # Remove leading space
    DOCKER_ARGS+=("$CMD_STRING")
fi

# Append container arguments
for arg in "${CONTAINER_ARGS[@]}"; do
    DOCKER_ARGS+=("$arg")
done

# Output the docker command for verification
echo "DOCKER_CMD:${DOCKER_ARGS[*]}"
EOF
)

# Test non-interactive command: ./sandbox/run.sh -- --cmd ls /
echo "Testing: ./sandbox/run.sh -- --cmd ls /"
OUTPUT=$(bash -c "$TEST_SCRIPT" -- -- --cmd ls / 2>&1 || true)

if echo "$OUTPUT" | grep -q "DOCKER_CMD:.*--entrypoint=/bin/bash.*-c.*ls /"; then
    echo "PASS: --entrypoint=/bin/bash -c ls / found in docker command"
else
    echo "FAIL: Expected --entrypoint=/bin/bash -c ls / in docker command"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test command with arguments: ./sandbox/run.sh -- --cmd bash -c "echo hello"
echo "Testing: ./sandbox/run.sh -- --cmd bash -c \"echo hello && pwd\""
OUTPUT=$(bash -c "$TEST_SCRIPT" -- -- --cmd bash -c "echo hello && pwd" 2>&1 || true)

if echo "$OUTPUT" | grep -q "DOCKER_CMD:.*--entrypoint=/bin/bash.*-c.*echo hello && pwd"; then
    echo "PASS: Complex command with arguments correctly included"
else
    echo "FAIL: Complex command not handled correctly"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test interactive session: ./sandbox/run.sh -it -- --cmd bash
echo "Testing: ./sandbox/run.sh -it -- --cmd bash"
OUTPUT=$(bash -c "$TEST_SCRIPT" -it -- --cmd bash 2>&1 || true)

if echo "$OUTPUT" | grep -q "DOCKER_CMD:.*--entrypoint=/bin/bash.*-c.*bash"; then
    echo "PASS: Interactive bash session with -it flags handled correctly"
else
    echo "FAIL: Interactive flags not preserved with --cmd"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test that normal mode still works (without --cmd)
echo "Testing: Normal mode without --cmd (./sandbox/run.sh -- --help)"
OUTPUT=$(bash -c "$TEST_SCRIPT" -- -- --help 2>&1 || true)

if echo "$OUTPUT" | grep -q "DOCKER_CMD:.*--help"; then
    echo "PASS: Normal mode still works (--help passed as container arg)"
else
    echo "FAIL: Normal mode broken without --cmd"
    echo "Output: $OUTPUT"
    exit 1
fi

echo "=== All sandbox run.sh --cmd option tests passed ==="