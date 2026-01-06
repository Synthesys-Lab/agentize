#!/usr/bin/env bash
# Test: wt spawn creates worktree in correct location (cross-project)

source "$(dirname "$0")/../common.sh"

test_info "wt spawn creates worktree in correct location"

WT_CLI="$PROJECT_ROOT/src/cli/wt.sh"

# Unset all git environment variables to ensure clean test environment
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_INDEX_VERSION GIT_COMMON_DIR

# Create temporary agentize repo and another project
TEST_AGENTIZE=$(mktemp -d)
TEST_PROJECT=$(mktemp -d)

# Setup test agentize repo
(
  cd "$TEST_AGENTIZE"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

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

  # Copy scripts
  mkdir -p scripts
  cp "$PROJECT_ROOT/scripts/worktree.sh" scripts/ 2>/dev/null || true
  cp "$WT_CLI" scripts/
  chmod +x src/cli/wt.sh
)

# Setup test project (different repo)
(
  cd "$TEST_PROJECT"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "project" > README.md
  git add README.md
  git commit -m "Project init"
)

# Test wt spawn from different project
(
  export AGENTIZE_HOME="$TEST_AGENTIZE"
  export PATH="$TEST_AGENTIZE/bin:$PATH"
  cd "$TEST_PROJECT"  # Run from different project

  # Source wt functions
  source "$TEST_AGENTIZE/src/cli/wt.sh"

  # Initialize first
  wt init

  # Create worktree using wt spawn
  wt spawn --no-agent 42

  # Verify worktree created in agentize repo, not current project
  if [ ! -d "$TEST_AGENTIZE/trees/issue-42" ]; then
    rm -rf "$TEST_AGENTIZE" "$TEST_PROJECT"
    test_fail "Worktree not created in AGENTIZE_HOME"
  fi

  if [ -d "$TEST_PROJECT/trees/issue-42" ]; then
    rm -rf "$TEST_AGENTIZE" "$TEST_PROJECT"
    test_fail "Worktree incorrectly created in current project"
  fi

  # Test wt list
  if ! wt list | grep -q "issue-42"; then
    rm -rf "$TEST_AGENTIZE" "$TEST_PROJECT"
    test_fail "wt list does not show worktree"
  fi

  # Test wt remove
  wt remove 42
  if [ -d "$TEST_AGENTIZE/trees/issue-42" ]; then
    rm -rf "$TEST_AGENTIZE" "$TEST_PROJECT"
    test_fail "wt remove did not remove worktree"
  fi
)

# Cleanup
rm -rf "$TEST_AGENTIZE" "$TEST_PROJECT"

test_pass "Cross-project wt spawn, list, and remove work correctly"
