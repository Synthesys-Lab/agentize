#!/usr/bin/env bash
# Test: session-init.sh sets AGENTIZE_HOME correctly in main and linked worktrees

source "$(dirname "$0")/../common.sh"

test_info "session-init.sh sets AGENTIZE_HOME correctly in main and linked worktrees"

# Unset all git environment variables to ensure clean test environment
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_INDEX_VERSION GIT_COMMON_DIR

# Create a temporary test repository
TEST_REPO_DIR=$(mktemp -d)
cd "$TEST_REPO_DIR"

# Initialize git repo
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Create initial commit
echo "test" > README.md
git add README.md
git commit -m "Initial commit"

# Copy necessary files from agentize
cp "$PROJECT_ROOT/Makefile" ./Makefile
mkdir -p scripts
cp "$PROJECT_ROOT/scripts/wt-cli.sh" ./scripts/wt-cli.sh
cp "$PROJECT_ROOT/scripts/lol-cli.sh" ./scripts/lol-cli.sh
mkdir -p .claude/hooks
cp "$PROJECT_ROOT/.claude/hooks/session-init.sh" ./.claude/hooks/session-init.sh

# Test 1: Verify AGENTIZE_HOME in main worktree
(
    # Source the hook in a subshell to isolate environment
    source ./.claude/hooks/session-init.sh

    # Get expected value from git
    EXPECTED=$(git rev-parse --show-toplevel)

    # Verify AGENTIZE_HOME is set correctly
    if [ -z "$AGENTIZE_HOME" ]; then
        cd /
        rm -rf "$TEST_REPO_DIR"
        test_fail "AGENTIZE_HOME not set in main worktree"
    fi

    if [ "$AGENTIZE_HOME" != "$EXPECTED" ]; then
        cd /
        rm -rf "$TEST_REPO_DIR"
        test_fail "AGENTIZE_HOME mismatch in main worktree: expected '$EXPECTED', got '$AGENTIZE_HOME'"
    fi
)

# Test 2: Verify AGENTIZE_HOME in linked worktree
# Create a linked worktree
mkdir -p trees
git worktree add trees/test-branch

# Change to linked worktree
cd trees/test-branch

(
    # Source the hook in a subshell to isolate environment
    source ../../.claude/hooks/session-init.sh

    # Get expected value from git
    EXPECTED=$(git rev-parse --show-toplevel)

    # Verify AGENTIZE_HOME is set correctly
    if [ -z "$AGENTIZE_HOME" ]; then
        cd /
        rm -rf "$TEST_REPO_DIR"
        test_fail "AGENTIZE_HOME not set in linked worktree"
    fi

    if [ "$AGENTIZE_HOME" != "$EXPECTED" ]; then
        cd /
        rm -rf "$TEST_REPO_DIR"
        test_fail "AGENTIZE_HOME mismatch in linked worktree: expected '$EXPECTED', got '$AGENTIZE_HOME'"
    fi
)

# Cleanup
cd /
rm -rf "$TEST_REPO_DIR"

test_pass "session-init.sh sets AGENTIZE_HOME correctly in both main and linked worktrees"
