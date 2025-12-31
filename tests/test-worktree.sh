#!/usr/bin/env bash
# Test for scripts/wt-cli.sh
# Tests worktree creation, listing, and removal via sourced functions

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
  # Test 1: Create worktree with custom description (truncated to 10 chars)
  echo "Test 1: Create worktree with custom description"
  cmd_create 42 test-feature

  if [ ! -d "trees/issue-42-test" ]; then
      echo -e "${RED}FAIL: Worktree directory not created (expected: issue-42-test)${NC}"
      exit 1
  fi

  if [ ! -f "trees/issue-42-test/CLAUDE.md" ]; then
      echo -e "${RED}FAIL: CLAUDE.md not bootstrapped${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: Worktree created and bootstrapped${NC}"

  echo ""
  # Test 2: List worktrees
  echo "Test 2: List worktrees"
  OUTPUT=$(cmd_list)
  if [[ ! "$OUTPUT" =~ "issue-42-test" ]]; then
      echo -e "${RED}FAIL: Worktree not listed${NC}"
      exit 1
  fi
  echo -e "${GREEN}PASS: Worktree listed${NC}"

  echo ""
  # Test 3: Verify branch exists
  echo "Test 3: Verify branch exists"
  if ! git branch | grep -q "issue-42-test"; then
      echo -e "${RED}FAIL: Branch not created${NC}"
      exit 1
  fi
  echo -e "${GREEN}PASS: Branch created${NC}"

  echo ""
  # Test 4: Remove worktree
  echo "Test 4: Remove worktree"
  cmd_remove 42

  if [ -d "trees/issue-42-test" ]; then
      echo -e "${RED}FAIL: Worktree directory still exists${NC}"
      exit 1
  fi
  echo -e "${GREEN}PASS: Worktree removed${NC}"

  echo ""
  # Test 5: Prune stale metadata
  echo "Test 5: Prune stale metadata"
  cmd_prune
  echo -e "${GREEN}PASS: Prune completed${NC}"

  echo ""
  # Test 6: Long title truncates to max length (default 10)
  echo "Test 6: Long title truncates to max length"
  cmd_create 99 this-is-a-very-long-suffix-that-should-be-truncated
  if [ ! -d "trees/issue-99-this-is-a" ]; then
      echo -e "${RED}FAIL: Long suffix not truncated to 10 chars${NC}"
      exit 1
  fi
  cmd_remove 99
  echo -e "${GREEN}PASS: Long suffix truncated${NC}"

  echo ""
  # Test 7: Short title preserved
  echo "Test 7: Short title preserved"
  cmd_create 88 short
  if [ ! -d "trees/issue-88-short" ]; then
      echo -e "${RED}FAIL: Short suffix not preserved${NC}"
      exit 1
  fi
  cmd_remove 88
  echo -e "${GREEN}PASS: Short suffix preserved${NC}"

  echo ""
  # Test 8: Word-boundary trimming
  echo "Test 8: Word-boundary trimming"
  cmd_create 77 very-long-name
  if [ ! -d "trees/issue-77-very-long" ]; then
      echo -e "${RED}FAIL: Word-boundary trim failed${NC}"
      exit 1
  fi
  cmd_remove 77
  echo -e "${GREEN}PASS: Word-boundary trim works${NC}"

  echo ""
  # Test 9: Env override changes limit
  echo "Test 9: Env override changes limit"
  WORKTREE_SUFFIX_MAX_LENGTH=5 cmd_create 66 test-feature
  if [ ! -d "trees/issue-66-test" ]; then
      echo -e "${RED}FAIL: Env override not applied (expected: issue-66-test)${NC}"
      exit 1
  fi
  cmd_remove 66
  echo -e "${GREEN}PASS: Env override works${NC}"

  echo ""
  # Test 10: Linked worktree regression - create worktree from linked worktree
  echo "Test 10: Linked worktree - create worktree from linked worktree"

  # Create first worktree
  cmd_create 55 first

  # cd into the linked worktree
  cd trees/issue-55-first

  # Source wt-cli.sh again in the linked worktree context
  source "$TEST_DIR/wt-cli.sh"

  # Try to create another worktree from inside the linked worktree
  # It should create the new worktree under the main repo root, not inside the linked worktree
  cmd_create 56 second

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

  # Cleanup
  cd /
  rm -rf "$TEST_DIR"

  echo ""
  echo -e "${GREEN}=== All tests passed ===${NC}"
)
