#!/usr/bin/env bash
# Test: wt spawn from linked worktree creates under main repo

source "$(dirname "$0")/../common.sh"

test_info "wt spawn from linked worktree creates under main repo"

# Source wt functions from project root
source "$PROJECT_ROOT/src/cli/wt.sh"

# Unset all git environment variables to ensure clean test environment
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_INDEX_VERSION GIT_COMMON_DIR

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
mkdir -p bin
cat > bin/gh <<'GHSTUB'
#!/usr/bin/env bash
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  issue_no="$3"
  case "$issue_no" in
    42|50|51) exit 0 ;;
    *) exit 1 ;;
  esac
fi
GHSTUB
chmod +x bin/gh

# Create first worktree and spawn another from it (wt functions already sourced via session-init.sh)
export AGENTIZE_HOME="$TEST_AGENTIZE"
export PATH="$TEST_AGENTIZE/bin:$PATH"

wt init

wt spawn --no-agent 50

# Now cd into the linked worktree and create another worktree
cd trees/issue-50

# Create another worktree from inside the linked worktree
wt spawn --no-agent 51

# Verify the new worktree is created under AGENTIZE_HOME, not inside the linked worktree
if [ ! -d "$TEST_AGENTIZE/trees/issue-51" ]; then
  cd /
  rm -rf "$TEST_AGENTIZE"
  test_fail "Worktree not created under main repo root"
fi

# Verify it's NOT created inside the linked worktree
if [ -d "trees/issue-51" ]; then
  cd /
  rm -rf "$TEST_AGENTIZE"
  test_fail "Worktree incorrectly created inside linked worktree"
fi

# Cleanup
cd /
rm -rf "$TEST_AGENTIZE"

test_pass "wt spawn from linked worktree creates under AGENTIZE_HOME"
