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

## Build

```bash
docker build -t agentize-sandbox ./sandbox
```

## Usage

```bash
docker run -it --rm agentize-sandbox
```