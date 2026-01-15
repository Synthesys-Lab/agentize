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
- `run.sh` - Docker run script with volume passthrough

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

## Build

```bash
docker build -t agentize-sandbox ./sandbox
```

Or use the Makefile:

```bash
make sandbox-build
```

## Usage with Volume Passthrough

Use `run.sh` to mount external resources into the container:

```bash
# Basic usage
./sandbox/run.sh

# Run with custom container name
./sandbox/run.sh my-container

# Pass arguments to the container
./sandbox/run.sh -- --help

# Run with --ccr flag for CCR mode
./sandbox/run.sh -- --ccr --help
```

The script automatically mounts:
- `~/.claude-code-router/config.json` -> `/home/agentizer/.claude-code-router/config.json` (read-only)
- `~/.config/gh` -> `/home/agentizer/.config/gh` (read-write, allows GH to refresh tokens)
- `~/.git-credentials` -> `/home/agentizer/.git-credentials` (read-only)
- `~/.gitconfig` -> `/home/agentizer/.gitconfig` (read-only)
- Current agentize project directory -> `/workspace/agentize`
- `GITHUB_TOKEN` environment variable (if set on host, passed to container for GH CLI auth)

Or use the Makefile:

```bash
make sandbox-run
make sandbox-run -- --help
```

## Entrypoint Modes

The container supports two modes via the entrypoint:

### Claude Code Mode (Default)

Without `--ccr` flag, runs Claude Code:

```bash
docker run agentize-sandbox claude --help
```

### CCR Mode

With `--ccr` flag, runs claude-code-router:

```bash
docker run agentize-sandbox ccr code --help
```

The `--ccr` flag can be used directly when running the container:

```bash
./sandbox/run.sh -- --ccr --help
```

## Testing

```bash
# Run PATH verification tests
./tests/sandbox-path-test.sh

# Run full sandbox build and verification tests
./tests/e2e/test-sandbox-build.sh
```