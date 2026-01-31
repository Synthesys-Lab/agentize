#!/usr/bin/env bash
# Test: wt init creates trees/main worktree

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

source "$TESTS_DIR/helpers-gh-mock.sh"

test_info "wt init creates trees/main worktree"

# Source wt functions from project root
source "$PROJECT_ROOT/src/cli/wt.sh"

clean_git_env

# Create temporary agentize repo
TEST_AGENTIZE=$(mktemp -d)

# Setup test agentize bare repo
SEED_DIR=$(mktemp -d)
cd "$SEED_DIR"
git init
git config user.email "test@example.com"
git config user.name "Test User"
echo "test" > README.md
git add README.md
git commit -m "Initial commit"

# Clone as bare repo
git clone --bare "$SEED_DIR" "$TEST_AGENTIZE"
rm -rf "$SEED_DIR"
cd "$TEST_AGENTIZE"

# Create gh stub for testing
create_gh_stub

# Test wt init (wt functions already sourced via session-init.sh)
export AGENTIZE_HOME="$TEST_AGENTIZE"

wt init

# Verify trees/main created
if [ ! -d "$TEST_AGENTIZE/trees/main" ]; then
  cd /
  rm -rf "$TEST_AGENTIZE"
  test_fail "wt init did not create trees/main"
fi

# Cleanup
cd /
rm -rf "$TEST_AGENTIZE"

test_pass "wt init creates trees/main"
