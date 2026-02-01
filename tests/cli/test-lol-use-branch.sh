#!/usr/bin/env bash
# Test: lol use-branch switches to remote branch and runs setup

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol use-branch switches to remote branch and runs setup"

# Create temp directory for test environment
TMP_DIR=$(make_temp_dir "test-lol-use-branch")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create mock remote repo
REMOTE_REPO="$TMP_DIR/remote.git"
git init -q --bare "$REMOTE_REPO"

# Create mock AGENTIZE_HOME with git repo
MOCK_AGENTIZE_HOME="$TMP_DIR/agentize"
mkdir -p "$MOCK_AGENTIZE_HOME"
git -C "$MOCK_AGENTIZE_HOME" init -q
git -C "$MOCK_AGENTIZE_HOME" config user.email "test@test.com"
git -C "$MOCK_AGENTIZE_HOME" config user.name "Test"

# Create a simple Makefile with setup target that creates a marker file
cat > "$MOCK_AGENTIZE_HOME/Makefile" << 'MAKEFILE'
.PHONY: setup
setup:
	@touch setup-was-called.marker
	@echo "Setup completed"
MAKEFILE

# Initial commit
cat > "$MOCK_AGENTIZE_HOME/README.md" << 'EOF_README'
# Mock Repo
EOF_README
git -C "$MOCK_AGENTIZE_HOME" add .
git -C "$MOCK_AGENTIZE_HOME" commit -q -m "Initial commit"

# Set main branch and push to origin

git -C "$MOCK_AGENTIZE_HOME" branch -M main
git -C "$MOCK_AGENTIZE_HOME" remote add origin "$REMOTE_REPO"
git -C "$MOCK_AGENTIZE_HOME" push -q -u origin main

# Create a feature branch on origin

git -C "$MOCK_AGENTIZE_HOME" checkout -q -b feature/test-branch
cat > "$MOCK_AGENTIZE_HOME/feature.txt" << 'EOF_FEATURE'
feature branch content
EOF_FEATURE
git -C "$MOCK_AGENTIZE_HOME" add feature.txt
git -C "$MOCK_AGENTIZE_HOME" commit -q -m "Add feature branch"
git -C "$MOCK_AGENTIZE_HOME" push -q -u origin feature/test-branch

# Return to main and delete local feature branch to force tracking checkout

git -C "$MOCK_AGENTIZE_HOME" checkout -q main
git -C "$MOCK_AGENTIZE_HOME" branch -D feature/test-branch

# Set up environment
export AGENTIZE_HOME="$MOCK_AGENTIZE_HOME"
source "$LOL_CLI"

# Test 1: Missing argument prints usage

test_info "Test 1: missing argument prints usage"

output=$(lol use-branch 2>&1 || true)
if ! echo "$output" | grep -q "Usage: lol use-branch"; then
    echo "Output:"
    echo "$output"
    test_fail "Expected usage guidance when missing branch"
fi

# Test 2: Dirty worktree guard

test_info "Test 2: dirty worktree guard"

echo "dirty" > "$MOCK_AGENTIZE_HOME/dirty.txt"
output=$(lol use-branch feature/test-branch 2>&1 || true)
if ! echo "$output" | grep -qi "uncommitted changes"; then
    echo "Output:"
    echo "$output"
    test_fail "Expected dirty worktree guard message"
fi

git -C "$MOCK_AGENTIZE_HOME" reset -q --hard
git -C "$MOCK_AGENTIZE_HOME" clean -q -fd

# Test 3: Switch to remote branch using shorthand

test_info "Test 3: switch to remote branch using shorthand"

rm -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker"
output=$(lol use-branch feature/test-branch 2>&1) || true

if [ ! -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker" ]; then
    echo "Output:"
    echo "$output"
    test_fail "make setup was not executed"
fi

current_branch=$(git -C "$MOCK_AGENTIZE_HOME" rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "feature/test-branch" ]; then
    echo "Output:"
    echo "$output"
    test_fail "Expected to be on feature/test-branch, got '$current_branch'"
fi

upstream=$(git -C "$MOCK_AGENTIZE_HOME" rev-parse --abbrev-ref --symbolic-full-name "@{u}")
if [ "$upstream" != "origin/feature/test-branch" ]; then
    echo "Upstream: $upstream"
    test_fail "Expected upstream to be origin/feature/test-branch"
fi

if ! echo "$output" | grep -q "reload\|exec"; then
    echo "Output:"
    echo "$output"
    test_fail "Output should include shell reload instructions"
fi

test_pass "lol use-branch switches to remote branch and runs setup"
