#!/bin/bash
# Run agentize container with volume passthrough
#
# This script mounts external resources into the container:
# - ~/.claude-code-router/config.json -> /home/agentizer/.claude-code-router/config.json
# - ~/.config/gh -> /home/agentizer/.config/gh (GitHub CLI credentials)
# - ~/.git-credentials -> /home/agentizer/.git-credentials
# - ~/.gitconfig -> /home/agentizer/.gitconfig
# - Current agentize project directory -> /workspace/agentize

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="agentize-sandbox"

# Determine if running interactively (has TTY and not piping)
if [ -t 0 ] && [ -t 1 ]; then
    INTERACTIVE_FLAGS="-it"
else
    INTERACTIVE_FLAGS="-t"
fi

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
SEEN_CMD=0
CUSTOM_CMD=()
while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--" ]]; then
        SEEN_DASH_DASH=1
        shift
        continue
    fi

    if [[ "$1" == "--cmd" ]]; then
        SEEN_CMD=1
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
        if [[ $SEEN_CMD -eq 1 ]]; then
            # Collect custom command arguments after --cmd
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

# 1. Passthrough claude-code-router config if exists
CCR_CONFIG="$HOME/.claude-code-router/config.json"
if [ -f "$CCR_CONFIG" ]; then
    DOCKER_ARGS+=("-v" "$CCR_CONFIG:/home/agentizer/.claude-code-router/config.json:ro")
fi

# 2. Passthrough GitHub CLI credentials
GH_CONFIG="$HOME/.config/gh"
if [ -d "$GH_CONFIG" ]; then
    DOCKER_ARGS+=("-v" "$GH_CONFIG:/home/agentizer/.config/gh:ro")
fi

# 3. Passthrough git credentials (if exists)
GIT_CREDS="$HOME/.git-credentials"
if [ -f "$GIT_CREDS" ]; then
    DOCKER_ARGS+=("-v" "$GIT_CREDS:/home/agentizer/.git-credentials:ro")
fi
GIT_CONFIG="$HOME/.gitconfig"
if [ -f "$GIT_CONFIG" ]; then
    DOCKER_ARGS+=("-v" "$GIT_CONFIG:/home/agentizer/.gitconfig:ro")
fi

# 4. Passthrough agentize project directory
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_ARGS+=("-v" "$PROJECT_DIR:/workspace/agentize")

# When --cmd is provided, override entrypoint to run custom command
if [ ${#CUSTOM_CMD[@]} -gt 0 ]; then
    DOCKER_ARGS+=("--entrypoint=/bin/bash")
    DOCKER_ARGS+=("-c")
    # Join the command arguments into a single string
    CMD_STRING=$(printf " %s" "${CUSTOM_CMD[@]}")
    CMD_STRING=${CMD_STRING:1}  # Remove leading space
    DOCKER_ARGS+=("$CMD_STRING")
else
    # Add working directory and image
    DOCKER_ARGS+=("-w" "/workspace/agentize")
    DOCKER_ARGS+=("$IMAGE_NAME")

    # Append container arguments
    for arg in "${CONTAINER_ARGS[@]}"; do
        DOCKER_ARGS+=("$arg")
    done
fi

# Execute docker run
docker "${DOCKER_ARGS[@]}"