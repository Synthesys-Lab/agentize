#!/usr/bin/env bash
# Test: wt init fails in non-bare repositories with clear error

source "$(dirname "$0")/../common.sh"

test_info "wt init fails in non-bare repositories with clear error"

# Create a NON-bare test repo
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Create initial commit
echo "test" > README.md
git add README.md
git commit -m "Initial commit"

# Copy src/cli/wt.sh as wt-cli.sh for test sourcing
cp "$PROJECT_ROOT/src/cli/wt.sh" ./wt-cli.sh
source ./wt-cli.sh

# Try to run wt init - should fail
if wt init 2>/dev/null; then
  cd /
  rm -rf "$TEST_DIR"
  test_fail "wt init should fail in non-bare repository"
fi

# Verify error message mentions bare repository requirement
error_output=$(wt init 2>&1 || true)
if ! echo "$error_output" | grep -qi "bare"; then
  cd /
  rm -rf "$TEST_DIR"
  test_fail "Error message should mention 'bare' repository requirement"
fi

# Clean up
cd /
rm -rf "$TEST_DIR"

test_pass "wt init correctly rejects non-bare repositories"
