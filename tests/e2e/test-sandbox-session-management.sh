#!/bin/bash
# Purpose: Test sandbox session management with tmux-based worktree + container combinations
# Expected: run.py subcommands (new, ls, rm, attach) work correctly with SQLite state

# Shared test helpers
set -e
SCRIPT_PATH="$0"
if [ -n "${BASH_SOURCE[0]-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
if [ "${SCRIPT_PATH%/*}" = "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="."
else
  SCRIPT_DIR="${SCRIPT_PATH%/*}"
fi
source "$SCRIPT_DIR/../common.sh"

set -e

# Skip if sandbox prerequisites are missing
if ! command -v uv >/dev/null 2>&1; then
  echo "SKIP: sandbox tests require 'uv'"
  exit 0
fi
if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: sandbox tests require podman or docker"
  exit 0
fi
runtime_ok=0
if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
  runtime_ok=1
fi
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  runtime_ok=1
fi
if [ "$runtime_ok" -ne 1 ]; then
  echo "SKIP: container runtime not available (podman/docker not running)"
  exit 0
fi

test_info "Testing sandbox session management"

# =============================================================================
# Test 1: Verify run.py has subcommand structure
# =============================================================================
test_info "Test 1: Verifying run.py subcommand structure"

# Check that run.py exists
if [ ! -f "$PROJECT_ROOT/sandbox/run.py" ]; then
    test_fail "sandbox/run.py does not exist"
fi

# Check for subcommand-related code patterns
if ! grep -q "subcommand\|add_subparsers\|new\|attach" "$PROJECT_ROOT/sandbox/run.py"; then
    test_fail "run.py should have subcommand structure (new, ls, rm, attach)"
fi

echo "Subcommand structure found"

# =============================================================================
# Test 2: Verify SQLite state management module exists
# =============================================================================
test_info "Test 2: Verifying SQLite state management"

# Check for SQLite-related imports or usage
if ! grep -q "sqlite3\|sqlite" "$PROJECT_ROOT/sandbox/run.py"; then
    test_fail "run.py should use SQLite for state management"
fi

echo "SQLite state management found"

# =============================================================================
# Test 3: Verify tmux is installed in Dockerfile
# =============================================================================
test_info "Test 3: Verifying tmux in Dockerfile"

if ! grep -q "tmux" "$PROJECT_ROOT/sandbox/Dockerfile"; then
    test_fail "Dockerfile should install tmux"
fi

echo "tmux installation found in Dockerfile"

# =============================================================================
# Test 4: Verify entrypoint.sh supports tmux session
# =============================================================================
test_info "Test 4: Verifying entrypoint.sh tmux support"

if ! grep -q "tmux" "$PROJECT_ROOT/sandbox/entrypoint.sh"; then
    test_fail "entrypoint.sh should support tmux sessions"
fi

echo "tmux support found in entrypoint.sh"

# =============================================================================
# Test 5: Verify UID/GID mapping support
# =============================================================================
test_info "Test 5: Verifying UID/GID mapping support"

# Check for UID/GID related code in run.py
if ! grep -q "getuid\|getgid\|userns\|--user" "$PROJECT_ROOT/sandbox/run.py"; then
    test_fail "run.py should support UID/GID mapping"
fi

echo "UID/GID mapping support found"

# =============================================================================
# Test 6: Verify worktree directory structure support
# =============================================================================
test_info "Test 6: Verifying worktree directory structure"

# Check for .wt directory handling
if ! grep -q "\.wt\|worktree" "$PROJECT_ROOT/sandbox/run.py"; then
    test_fail "run.py should handle .wt worktree directory"
fi

echo "Worktree directory structure support found"

# =============================================================================
# Test 7: Verify container naming convention
# =============================================================================
test_info "Test 7: Verifying container naming convention"

# Check for agentize-sb- prefix in container naming
if ! grep -q "agentize-sb-\|container.*name" "$PROJECT_ROOT/sandbox/run.py"; then
    test_fail "run.py should use agentize-sb-<name> container naming"
fi

echo "Container naming convention found"

test_pass "Sandbox session management structure verified"
