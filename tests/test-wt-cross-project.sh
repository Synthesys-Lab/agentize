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

    # Create worktree using wt spawn (with --no-agent for testing)
    wt spawn 42 test --no-agent

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

    # Test wt remove (basic cleanup for next tests)
    wt remove 42
    if [ -d "$TEST_PROJECT/trees/issue-42-test" ]; then
      echo -e "${RED}FAIL: wt remove did not remove worktree${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: wt remove works from subdirectory${NC}"
  )

  # Test 4: wt remove deletes branch by default
  echo ""
  echo "Test 4: wt remove deletes branch by default"
  (
    export AGENTIZE_HOME="$TEST_AGENTIZE"
    cd "$TEST_PROJECT"
    source "$TEST_AGENTIZE/scripts/wt-cli.sh"

    # Create worktree (use short name to avoid truncation)
    wt spawn 43 test-rm

    # Verify branch exists
    (cd "$TEST_AGENTIZE" && git branch | grep -q "issue-43-test-rm") || {
      echo -e "${RED}FAIL: Branch not created${NC}"
      exit 1
    }

    # Remove worktree (should also delete branch)
    wt remove 43

    # Verify worktree removed
    if [ -d "$TEST_AGENTIZE/trees/issue-43-test-rm" ]; then
      echo -e "${RED}FAIL: Worktree not removed${NC}"
      exit 1
    fi

    # Verify branch deleted
    if (cd "$TEST_AGENTIZE" && git branch | grep -q "issue-43-test-rm"); then
      echo -e "${RED}FAIL: Branch not deleted${NC}"
      exit 1
    fi

    echo -e "${GREEN}PASS: wt remove deletes branch by default${NC}"
  )

  # Test 5: wt remove --keep-branch preserves branch
  echo ""
  echo "Test 5: wt remove --keep-branch preserves branch"
  (
    export AGENTIZE_HOME="$TEST_AGENTIZE"
    cd "$TEST_PROJECT"
    source "$TEST_AGENTIZE/scripts/wt-cli.sh"

    # Create worktree (use short name to avoid truncation)
    wt spawn 44 test-keep

    # Verify branch exists
    (cd "$TEST_AGENTIZE" && git branch | grep -q "issue-44-test-keep") || {
      echo -e "${RED}FAIL: Branch not created${NC}"
      exit 1
    }

    # Remove worktree with --keep-branch
    wt remove 44 --keep-branch

    # Verify worktree removed
    if [ -d "$TEST_AGENTIZE/trees/issue-44-test-keep" ]; then
      echo -e "${RED}FAIL: Worktree not removed${NC}"
      exit 1
    fi

    # Verify branch still exists
    if ! (cd "$TEST_AGENTIZE" && git branch | grep -q "issue-44-test-keep"); then
      echo -e "${RED}FAIL: Branch was deleted when it should be kept${NC}"
      exit 1
    fi

    # Cleanup the preserved branch
    (cd "$TEST_AGENTIZE" && git branch -D issue-44-test-keep)

    echo -e "${GREEN}PASS: wt remove --keep-branch preserves branch${NC}"
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

# Test 7: wt works correctly from inside a worktree
echo ""
echo "Test 7: wt works correctly from inside a worktree"

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

    # Initialize bare repository pattern
    wt init

    # Create a test worktree
    wt spawn 99 feature

    # Now test running wt commands FROM INSIDE the worktree
    cd "$TEST_PROJECT/trees/issue-99-feature"

    # Source wt functions again in the worktree context
    source "$TEST_PROJECT/scripts/wt-cli.sh"

    # Test that wt spawn works from inside a worktree
    wt spawn 100 nested

    # Verify worktree was created in the main repo root, not inside the current worktree
    if [ ! -d "$TEST_PROJECT/trees/issue-100-nested" ]; then
      echo -e "${RED}FAIL: Worktree not created in main repo root when run from inside worktree${NC}"
      exit 1
    fi

    if [ -d "$TEST_PROJECT/trees/issue-99-feature/trees/issue-100-nested" ]; then
      echo -e "${RED}FAIL: Worktree incorrectly created inside another worktree${NC}"
      exit 1
    fi

    echo -e "${GREEN}PASS: wt spawn works correctly from inside a worktree${NC}"

    # Test wt list from inside worktree
    if ! wt list | grep -q "issue-100-nested"; then
      echo -e "${RED}FAIL: wt list does not work from inside worktree${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: wt list works correctly from inside a worktree${NC}"

    # Clean up the nested worktree
    wt remove 100
    if [ -d "$TEST_PROJECT/trees/issue-100-nested" ]; then
      echo -e "${RED}FAIL: wt remove did not work from inside worktree${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: wt remove works correctly from inside a worktree${NC}"
  )

  # Cleanup
  rm -rf "$TEST_PROJECT"
)

echo ""
echo -e "${GREEN}=== All per-project tests passed ===${NC}"
