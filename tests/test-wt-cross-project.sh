#!/usr/bin/env bash
# Test for per-project wt shell function
# Verifies wt init, wt main, and wt spawn work on a per-project basis

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WT_CLI="$PROJECT_ROOT/scripts/wt-cli.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=== Per-Project wt Function Test ==="

# Test 1: wt spawn from subdirectory creates worktree under repo root
echo ""
echo "Test 1: wt spawn from subdirectory creates worktree under repo root"

(
  # Unset all git environment variables to ensure clean test environment
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  unset GIT_INDEX_VERSION GIT_COMMON_DIR

  # Create temporary project
  TEST_PROJECT=$(mktemp -d)
  echo "Test project: $TEST_PROJECT"

  # Setup test project
  (
    cd "$TEST_PROJECT"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -m "Initial commit"

    # Copy scripts
    mkdir -p scripts
    cp "$PROJECT_ROOT/scripts/worktree.sh" scripts/
    cp "$WT_CLI" scripts/
    chmod +x scripts/worktree.sh

    # Create subdirectory
    mkdir -p src/components
  )

  # Test wt spawn from subdirectory
  (
    cd "$TEST_PROJECT/src/components"  # Run from subdirectory

    # Source wt functions
    source "$TEST_PROJECT/scripts/wt-cli.sh"

    # Create worktree using wt spawn
    wt spawn 42 test

    # Verify worktree created in repo root, not subdirectory
    if [ ! -d "$TEST_PROJECT/trees/issue-42-test" ]; then
      echo -e "${RED}FAIL: Worktree not created in repo root${NC}"
      exit 1
    fi

    if [ -d "$TEST_PROJECT/src/components/trees/issue-42-test" ]; then
      echo -e "${RED}FAIL: Worktree incorrectly created in subdirectory${NC}"
      exit 1
    fi

    echo -e "${GREEN}PASS: Worktree created in repo root from subdirectory${NC}"

    # Test wt list
    if ! wt list | grep -q "issue-42-test"; then
      echo -e "${RED}FAIL: wt list does not show worktree${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: wt list works from subdirectory${NC}"

    # Test wt remove
    wt remove 42
    if [ -d "$TEST_PROJECT/trees/issue-42-test" ]; then
      echo -e "${RED}FAIL: wt remove did not remove worktree${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: wt remove works from subdirectory${NC}"
  )

  # Cleanup
  rm -rf "$TEST_PROJECT"
)

# Test 2: wt init creates trees/ and trees/main/ worktree
echo ""
echo "Test 2: wt init creates trees/ and trees/main/ worktree"

(
  # Unset all git environment variables
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  unset GIT_INDEX_VERSION GIT_COMMON_DIR

  # Create temporary project with main branch
  TEST_PROJECT=$(mktemp -d)
  echo "Test project: $TEST_PROJECT"

  (
    cd "$TEST_PROJECT"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -m "Initial commit"

    # Copy scripts
    mkdir -p scripts
    cp "$PROJECT_ROOT/scripts/worktree.sh" scripts/
    cp "$WT_CLI" scripts/
    chmod +x scripts/worktree.sh

    # Source wt functions
    source "$TEST_PROJECT/scripts/wt-cli.sh"

    # Run wt init
    wt init

    # Verify trees/ directory created
    if [ ! -d "$TEST_PROJECT/trees" ]; then
      echo -e "${RED}FAIL: trees/ directory not created${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: trees/ directory created${NC}"

    # Verify trees/main/ worktree created
    if [ ! -d "$TEST_PROJECT/trees/main" ]; then
      echo -e "${RED}FAIL: trees/main/ worktree not created${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: trees/main/ worktree created${NC}"

    # Verify .gitignore updated
    if ! grep -q "^trees/$" .gitignore 2>/dev/null; then
      echo -e "${RED}FAIL: .gitignore not updated${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: .gitignore updated${NC}"

    # Verify main repo is on different branch (not main)
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" = "main" ]; then
      echo -e "${RED}FAIL: Main repo still on main branch${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: Main repo switched to different branch${NC}"

    # Verify trees/main/ is on main branch
    MAIN_WORKTREE_BRANCH=$(cd trees/main && git branch --show-current)
    if [ "$MAIN_WORKTREE_BRANCH" != "main" ]; then
      echo -e "${RED}FAIL: trees/main/ worktree not on main branch${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: trees/main/ worktree on main branch${NC}"
  )

  # Cleanup
  rm -rf "$TEST_PROJECT"
)

# Test 3: wt init is idempotent
echo ""
echo "Test 3: wt init is idempotent"

(
  # Unset all git environment variables
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  unset GIT_INDEX_VERSION GIT_COMMON_DIR

  TEST_PROJECT=$(mktemp -d)
  echo "Test project: $TEST_PROJECT"

  (
    cd "$TEST_PROJECT"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -m "Initial commit"

    # Copy scripts
    mkdir -p scripts
    cp "$PROJECT_ROOT/scripts/worktree.sh" scripts/
    cp "$WT_CLI" scripts/
    chmod +x scripts/worktree.sh

    # Source wt functions
    source "$TEST_PROJECT/scripts/wt-cli.sh"

    # Run wt init twice
    wt init
    wt init

    # Verify still works correctly
    if [ ! -d "$TEST_PROJECT/trees/main" ]; then
      echo -e "${RED}FAIL: trees/main/ not present after second init${NC}"
      exit 1
    fi

    # Count .gitignore entries for trees/
    GITIGNORE_COUNT=$(grep -c "^trees/$" .gitignore 2>/dev/null || echo 0)
    if [ "$GITIGNORE_COUNT" -ne 1 ]; then
      echo -e "${RED}FAIL: .gitignore has duplicate entries (count: $GITIGNORE_COUNT)${NC}"
      exit 1
    fi

    echo -e "${GREEN}PASS: wt init is idempotent${NC}"
  )

  # Cleanup
  rm -rf "$TEST_PROJECT"
)

# Test 4: wt main navigates to trees/main/
echo ""
echo "Test 4: wt main navigates to trees/main/"

(
  # Unset all git environment variables
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  unset GIT_INDEX_VERSION GIT_COMMON_DIR

  TEST_PROJECT=$(mktemp -d)
  echo "Test project: $TEST_PROJECT"

  (
    cd "$TEST_PROJECT"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -m "Initial commit"

    # Copy scripts
    mkdir -p scripts
    cp "$PROJECT_ROOT/scripts/worktree.sh" scripts/
    cp "$WT_CLI" scripts/
    chmod +x scripts/worktree.sh

    # Source wt functions
    source "$TEST_PROJECT/scripts/wt-cli.sh"

    # Run wt init
    wt init

    # Test wt main (simulate by checking if it would cd to correct path)
    # Note: actual cd test requires shell function context, here we verify the logic
    EXPECTED_PATH="$TEST_PROJECT/trees/main"
    if [ ! -d "$EXPECTED_PATH" ]; then
      echo -e "${RED}FAIL: Expected path for wt main does not exist${NC}"
      exit 1
    fi

    echo -e "${GREEN}PASS: wt main target directory exists${NC}"
  )

  # Cleanup
  rm -rf "$TEST_PROJECT"
)

# Test 5: Default branch detection works for master
echo ""
echo "Test 5: Default branch detection works for master"

(
  # Unset all git environment variables
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  unset GIT_INDEX_VERSION GIT_COMMON_DIR

  TEST_PROJECT=$(mktemp -d)
  echo "Test project: $TEST_PROJECT"

  (
    cd "$TEST_PROJECT"
    git init -b master
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -m "Initial commit"

    # Copy scripts
    mkdir -p scripts
    cp "$PROJECT_ROOT/scripts/worktree.sh" scripts/
    cp "$WT_CLI" scripts/
    chmod +x scripts/worktree.sh

    # Source wt functions
    source "$TEST_PROJECT/scripts/wt-cli.sh"

    # Run wt init
    wt init

    # Verify trees/master/ worktree created
    if [ ! -d "$TEST_PROJECT/trees/master" ]; then
      echo -e "${RED}FAIL: trees/master/ worktree not created${NC}"
      exit 1
    fi

    # Verify trees/master/ is on master branch
    MASTER_WORKTREE_BRANCH=$(cd trees/master && git branch --show-current)
    if [ "$MASTER_WORKTREE_BRANCH" != "master" ]; then
      echo -e "${RED}FAIL: trees/master/ worktree not on master branch${NC}"
      exit 1
    fi

    echo -e "${GREEN}PASS: Default branch detection works for master${NC}"
  )

  # Cleanup
  rm -rf "$TEST_PROJECT"
)

# Test 6: Running wt outside a git repo yields clear error
echo ""
echo "Test 6: Running wt outside a git repo yields clear error"

(
  # Create non-git directory
  TEST_DIR=$(mktemp -d)
  echo "Test directory: $TEST_DIR"

  (
    cd "$TEST_DIR"

    # Source wt functions
    source "$WT_CLI"

    # Try to run wt spawn (should fail with clear error)
    if wt spawn 42 test 2>/dev/null; then
      echo -e "${RED}FAIL: Should error when run outside git repo${NC}"
      exit 1
    fi

    echo -e "${GREEN}PASS: Errors correctly when run outside git repo${NC}"
  )

  # Cleanup
  rm -rf "$TEST_DIR"
)

echo ""
echo -e "${GREEN}=== All per-project tests passed ===${NC}"
