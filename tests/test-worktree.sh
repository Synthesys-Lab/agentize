#!/usr/bin/env bash
# Purpose: Test for scripts/wt-cli.sh worktree functionality
# Expected: Validates worktree creation, listing, and removal via sourced functions

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WT_CLI="$PROJECT_ROOT/scripts/wt-cli.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=== Worktree Function Test ==="

# Run tests in a subshell with unset git environment variables
(
  # Unset all git environment variables to ensure clean test environment
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  unset GIT_INDEX_VERSION GIT_COMMON_DIR

  # Create a temporary test repository
  TEST_DIR=$(mktemp -d)
  echo "Test directory: $TEST_DIR"

  cd "$TEST_DIR"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Copy wt-cli.sh to test repo
  cp "$WT_CLI" ./wt-cli.sh

  # Copy CLAUDE.md for bootstrap testing
  echo "Test CLAUDE.md" > CLAUDE.md

  # Source the library
  source ./wt-cli.sh

  echo ""
  # Test 1: init creates trees/main worktree
  echo "Test 1: init creates trees/main worktree"
  cmd_init

  if [ ! -d "trees/main" ]; then
      echo -e "${RED}FAIL: trees/main directory not created${NC}"
      exit 1
  fi

  # Verify it's on main branch
  BRANCH=$(git -C trees/main branch --show-current)
  if [[ "$BRANCH" != "main" ]] && [[ "$BRANCH" != "master" ]]; then
      echo -e "${RED}FAIL: trees/main not on main/master branch (got: $BRANCH)${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: init created trees/main${NC}"

  echo ""
  # Test 2: spawn fails without init (cleanup trees/main first)
  echo "Test 2: spawn requires init (trees/main must exist)"
  rm -rf trees/main

  if cmd_create --no-agent 99 test-fail 2>/dev/null; then
      echo -e "${RED}FAIL: spawn should fail when trees/main is missing${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: spawn correctly requires init${NC}"

  # Re-initialize for remaining tests
  cmd_init

  echo ""
  # Test 3: Create worktree with custom description (truncated to 10 chars)
  echo "Test 3: Create worktree with custom description"
  cmd_create --no-agent 42 test-feature

  if [ ! -d "trees/issue-42-test" ]; then
      echo -e "${RED}FAIL: Worktree directory not created (expected: issue-42-test)${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: Worktree created${NC}"

  echo ""
  # Test 4: List worktrees
  echo "Test 4: List worktrees"
  OUTPUT=$(cmd_list)
  if [[ ! "$OUTPUT" =~ "issue-42-test" ]]; then
      echo -e "${RED}FAIL: Worktree not listed${NC}"
      exit 1
  fi
  echo -e "${GREEN}PASS: Worktree listed${NC}"

  echo ""
  # Test 5: Verify branch exists
  echo "Test 5: Verify branch exists"
  if ! git branch | grep -q "issue-42-test"; then
      echo -e "${RED}FAIL: Branch not created${NC}"
      exit 1
  fi
  echo -e "${GREEN}PASS: Branch created${NC}"

  echo ""
  # Test 6: Remove worktree
  echo "Test 6: Remove worktree"
  cmd_remove 42

  if [ -d "trees/issue-42-test" ]; then
      echo -e "${RED}FAIL: Worktree directory still exists${NC}"
      exit 1
  fi
  echo -e "${GREEN}PASS: Worktree removed${NC}"

  echo ""
  # Test 7: Prune stale metadata
  echo "Test 7: Prune stale metadata"
  cmd_prune
  echo -e "${GREEN}PASS: Prune completed${NC}"

  echo ""
  # Test 8: Long title truncates to max length (default 10)
  echo "Test 8: Long title truncates to max length"
  cmd_create --no-agent 99 this-is-a-very-long-suffix-that-should-be-truncated
  if [ ! -d "trees/issue-99-this-is-a" ]; then
      echo -e "${RED}FAIL: Long suffix not truncated to 10 chars${NC}"
      exit 1
  fi
  cmd_remove 99
  echo -e "${GREEN}PASS: Long suffix truncated${NC}"

  echo ""
  # Test 9: Short title preserved
  echo "Test 9: Short title preserved"
  cmd_create --no-agent 88 short
  if [ ! -d "trees/issue-88-short" ]; then
      echo -e "${RED}FAIL: Short suffix not preserved${NC}"
      exit 1
  fi
  cmd_remove 88
  echo -e "${GREEN}PASS: Short suffix preserved${NC}"

  echo ""
  # Test 10: Word-boundary trimming
  echo "Test 10: Word-boundary trimming"
  cmd_create --no-agent 77 very-long-name
  if [ ! -d "trees/issue-77-very-long" ]; then
      echo -e "${RED}FAIL: Word-boundary trim failed${NC}"
      exit 1
  fi
  cmd_remove 77
  echo -e "${GREEN}PASS: Word-boundary trim works${NC}"

  echo ""
  # Test 11: Env override changes limit
  echo "Test 11: Env override changes limit"
  WORKTREE_SUFFIX_MAX_LENGTH=5 cmd_create --no-agent 66 test-feature
  if [ ! -d "trees/issue-66-test" ]; then
      echo -e "${RED}FAIL: Env override not applied (expected: issue-66-test)${NC}"
      exit 1
  fi
  cmd_remove 66
  echo -e "${GREEN}PASS: Env override works${NC}"

  echo ""
  # Test 12: Linked worktree regression - create worktree from linked worktree
  echo "Test 12: Linked worktree - create worktree from linked worktree"

  # Create first worktree
  cmd_create --no-agent 55 first

  # cd into the linked worktree
  cd trees/issue-55-first

  # Source wt-cli.sh again in the linked worktree context
  source "$TEST_DIR/wt-cli.sh"

  # Try to create another worktree from inside the linked worktree
  # It should create the new worktree under the main repo root, not inside the linked worktree
  cmd_create --no-agent 56 second

  # Verify the new worktree is created under main repo root
  if [ ! -d "$TEST_DIR/trees/issue-56-second" ]; then
      echo -e "${RED}FAIL: Worktree not created under main repo root${NC}"
      exit 1
  fi

  # Verify it's NOT created inside the linked worktree
  if [ -d "trees/issue-56-second" ]; then
      echo -e "${RED}FAIL: Worktree incorrectly created inside linked worktree${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: Linked worktree creates under main repo root${NC}"

  # Cleanup - go back to main repo
  cd "$TEST_DIR"
  cmd_remove 55
  cmd_remove 56

  # Test 13: Metadata-driven default branch selection
  echo ""
  echo "Test 13: Metadata-driven default branch (trunk via .agentize.yaml)"

  # Create a new test repo with non-standard default branch
  TEST_DIR2=$(mktemp -d)
  cd "$TEST_DIR2"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit on trunk branch
  git checkout -b trunk
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Create .agentize.yaml specifying trunk as default
  cat > .agentize.yaml <<EOF
project:
  name: test-project
  lang: python
git:
  default_branch: trunk
EOF

  # Copy wt-cli.sh
  cp "$WT_CLI" ./wt-cli.sh
  echo "Test CLAUDE.md" > CLAUDE.md

  # Source the library
  source ./wt-cli.sh

  # Initialize first
  cmd_init

  # Create worktree (should use trunk, not main/master)
  cmd_create --no-agent 100 test-trunk

  # Verify worktree was created
  if [ ! -d "trees/issue-100-test-trunk" ]; then
    echo -e "${RED}FAIL: Worktree not created with metadata-driven branch${NC}"
    exit 1
  fi

  # Verify it's based on trunk branch
  BRANCH_BASE=$(git -C "trees/issue-100-test-trunk" log --oneline -1)
  TRUNK_COMMIT=$(git log trunk --oneline -1)
  if [[ "$BRANCH_BASE" != "$TRUNK_COMMIT" ]]; then
    echo -e "${RED}FAIL: Worktree not based on trunk branch${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: Metadata-driven default branch works${NC}"

  # Cleanup test repo 2
  cd /
  rm -rf "$TEST_DIR2"

  # Test 14: cmd_main --path returns absolute path to trees/main
  echo ""
  echo "Test 14: cmd_main --path returns absolute path to trees/main"

  # Create fresh test repo
  TEST_DIR3=$(mktemp -d)
  cd "$TEST_DIR3"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

  cp "$WT_CLI" ./wt-cli.sh
  source ./wt-cli.sh

  # Initialize
  cmd_init

  # Test --path output
  MAIN_PATH=$(cmd_main --path)
  EXPECTED_PATH="$TEST_DIR3/trees/main"

  if [[ "$MAIN_PATH" != "$EXPECTED_PATH" ]]; then
    echo -e "${RED}FAIL: cmd_main --path returned wrong path${NC}"
    echo "Expected: $EXPECTED_PATH"
    echo "Got: $MAIN_PATH"
    exit 1
  fi

  echo -e "${GREEN}PASS: cmd_main --path returns correct absolute path${NC}"

  # Test 15: cmd_main --path respects worktree.trees_dir from .agentize.yaml
  echo ""
  echo "Test 15: cmd_main --path respects worktree.trees_dir override"

  # Create .agentize.yaml with custom trees_dir
  cat > .agentize.yaml <<EOF
git:
  default_branch: main
worktree:
  trees_dir: custom-trees
EOF

  # Initialize with custom trees_dir
  rm -rf trees
  cmd_init

  # Test --path output with custom trees_dir
  CUSTOM_PATH=$(cmd_main --path)
  EXPECTED_CUSTOM_PATH="$TEST_DIR3/custom-trees/main"

  if [[ "$CUSTOM_PATH" != "$EXPECTED_CUSTOM_PATH" ]]; then
    echo -e "${RED}FAIL: cmd_main --path did not respect worktree.trees_dir${NC}"
    echo "Expected: $EXPECTED_CUSTOM_PATH"
    echo "Got: $CUSTOM_PATH"
    exit 1
  fi

  echo -e "${GREEN}PASS: cmd_main --path respects worktree.trees_dir${NC}"

  # Test 16: cmd_main --path fails when main worktree missing
  echo ""
  echo "Test 16: cmd_main --path fails when main worktree missing"

  # Remove main worktree
  rm -rf custom-trees/main
  git worktree prune

  # Test that --path fails with non-zero exit
  if cmd_main --path >/dev/null 2>&1; then
    echo -e "${RED}FAIL: cmd_main --path should fail when main worktree missing${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: cmd_main --path fails correctly when main worktree missing${NC}"

  # Cleanup test repo 3
  cd /
  rm -rf "$TEST_DIR3"

  # Cleanup original test repo
  cd /
  rm -rf "$TEST_DIR"

  echo ""
  echo -e "${GREEN}=== All tests passed ===${NC}"
)
