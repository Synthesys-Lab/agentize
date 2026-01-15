# Sandbox

Development environment container for agentize SDK.

## Purpose

This directory contains the Docker sandbox environment used for:
- Testing the agentize SDK in a controlled environment
- Development workflows requiring isolated dependencies
- CI/CD pipeline validation

## Contents

- `Dockerfile` - Docker image definition with all required tools
- `install.sh` - Claude Code installation script (copied into container)
- `entrypoint.sh` - Container entrypoint with ccr/claude routing
- `run.py` - Python-based container runner with volume passthrough and auto-build
- `pyproject.toml` - Python project configuration

## User

The container runs as the `agentizer` user with sudo privileges.

## Installed Tools

- Node.js 20.x LTS
- Python 3.12 with uv package manager
- SDKMAN for Java/SDK management
- Git, curl, wget, and other base utilities
- Playwright with bundled Chromium
- claude-code-router
- Claude Code
- GitHub CLI

## Container Runtime

This sandbox supports both Docker and Podman. The runtime is detected in priority order:

1. **Local config file**: `sandbox/agentize.toml` or `./agentize.toml`
2. **Global config file**: `~/.config/agentize/agentize.toml`
3. **CONTAINER_RUNTIME** environment variable
4. **Auto-detection**: Podman preferred if available, falls back to Docker

### Local Config File Format

Create `sandbox/agentize.toml`:

```toml
[container]
runtime = "podman"  # or "docker"
```

## Automatic Build

The `run.py` script automatically handles container image building:

- **First run**: Builds the image automatically if it doesn't exist
- **File changes**: Rebuilds when `Dockerfile`, `install.sh`, or `entrypoint.sh` change
- **Force rebuild**: Use `--build` flag to force a rebuild

## Build

```bash
# Build/rebuild the image (uses local config or auto-detection)
make sandbox-build
python3 ./sandbox/run.py --build

# Build with custom architecture
podman build --build-arg HOST_ARCH=arm64 -t agentize-sandbox ./sandbox
```

## Usage with Volume Passthrough

Use `run.py` to mount external resources into the container:

```bash
# Basic usage (auto-builds if needed)
python3 ./sandbox/run.py

# Run with custom container name
python3 ./sandbox/run.py my-container

# Pass arguments to the container
python3 ./sandbox/run.py -- --help

# Run with --ccr flag for CCR mode
python3 ./sandbox/run.py -- --ccr --help

# Execute custom command
python3 ./sandbox/run.py --cmd -- ls /workspace

# Force rebuild the image
python3 ./sandbox/run.py --build
```

Or use the Makefile:

```bash
make sandbox-run
make sandbox-run -- --help
```

The script automatically mounts:
- `~/.claude-code-router/config.json` -> `/home/agentizer/.claude-code-router/config.json` (read-only)
- `~/.config/gh` -> `/home/agentizer/.config/gh` (read-write, allows GH to refresh tokens)
- `~/.git-credentials` -> `/home/agentizer/.git-credentials` (read-only)
- `~/.gitconfig` -> `/home/agentizer/.gitconfig` (read-only)
- Current agentize project directory -> `/workspace/agentize`
- `GITHUB_TOKEN` environment variable (if set on host, passed to container for GH CLI auth)

## Entrypoint Modes

The container supports two modes via the entrypoint:

### Claude Code Mode (Default)

Without `--ccr` flag, runs Claude Code:

```bash
python3 ./sandbox/run.py -- claude --help
```

### CCR Mode

With `--ccr` flag, runs claude-code-router:

```bash
python3 ./sandbox/run.py -- --ccr --help
```

## Testing

```bash
# Run PATH verification tests
./tests/sandbox-path-test.sh

# Run full sandbox build and verification tests
./tests/e2e/test-sandbox-build.sh
```