#!/bin/bash
# Purpose: Test sandbox session management with tmux-based worktree + container combinations
# Expected: run.py subcommands (new, ls, rm, attach) work correctly with SQLite state

# Inlined shared test helpers (former tests/common.sh)
set -e

# ============================================================
# Test isolation: Clear Telegram environment variables
# ============================================================
# Prevents tests from accidentally sending Telegram API requests
# when developer environments have these variables set
unset AGENTIZE_USE_TG TG_API_TOKEN TG_CHAT_ID TG_ALLOWED_USER_IDS TG_APPROVAL_TIMEOUT_SEC TG_POLL_INTERVAL_SEC

# ============================================================
# Project root detection
# ============================================================

# Helper function to get the current project root (current worktree being tested)
# This is different from AGENTIZE_HOME which points to the agentize framework installation
get_project_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Get project root using shell-neutral approach
# For test isolation, always use the current worktree (ignore parent AGENTIZE_HOME)
PROJECT_ROOT="$(get_project_root)"
if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: Cannot determine project root. Run from git repo."
  exit 1
fi

# Export AGENTIZE_HOME for tests - this is the framework installation path
# Tests use the current project root as the framework location
export AGENTIZE_HOME="$PROJECT_ROOT"

TESTS_DIR="$PROJECT_ROOT/tests"

# ============================================================
# Color constants for terminal output
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================
# Test result helpers
# ============================================================

# Print test pass message and exit with success
# Usage: test_pass "message"
test_pass() {
  echo -e "${GREEN}✓ Test passed: $1${NC}"
  exit 0
}

# Print test fail message and exit with failure
# Usage: test_fail "message"
test_fail() {
  echo -e "${RED}✗ Test failed: $1${NC}"
  exit 1
}

# Print test info message
# Usage: test_info "message"
test_info() {
  echo -e "${BLUE}>>> $1${NC}"
}

# ============================================================
# Git environment cleanup
# ============================================================

# Clean all git environment variables to ensure isolated test environment
# Usage: clean_git_env
clean_git_env() {
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
    unset GIT_INDEX_VERSION GIT_COMMON_DIR
}

# ============================================================
# Resource management
# ============================================================

# Create a temporary directory under .tmp and return its path
# Usage: TMP_DIR=$(make_temp_dir "test-name")
make_temp_dir() {
  local test_name="$1"
  local tmp_dir="$PROJECT_ROOT/.tmp/$test_name"
  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  echo "$tmp_dir"
}

# Clean up a directory
# Usage: cleanup_dir "$TMP_DIR"
cleanup_dir() {
  local dir="$1"
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    rm -rf "$dir"
  fi
}

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
