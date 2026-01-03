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

  # Create gh stub that returns deterministic titles
  mkdir -p bin
  cat > bin/gh <<'GHSTUB'
#!/usr/bin/env bash
# Stub gh command for testing
case "$1" in
  issue)
    if [ "$2" = "view" ]; then
      issue_no="$3"
      case "$issue_no" in
        42) echo '{"title":"Test feature"}' ;;
        99) echo '{"title":"Test fail"}' ;;
        88) echo '{"title":"Short"}' ;;
        77) echo '{"title":"Very long name"}' ;;
        66) echo '{"title":"Test feature"}' ;;
        55) echo '{"title":"First"}' ;;
        56) echo '{"title":"Second"}' ;;
        100) echo '{"title":"Test trunk"}' ;;
        200) echo '{"title":"Test hook"}' ;;
        210) echo '{"title":"Unmerged test"}' ;;
        211) echo '{"title":"Force test"}' ;;
        300) echo '{"title":"Test YOLO"}' ;;
        301) echo '{"title":"Test after"}' ;;
        350) echo '{"title":"Custom desc test"}' ;;
        *) exit 1 ;;
      esac
    fi
    ;;
esac
GHSTUB
  chmod +x bin/gh
  export PATH="$PWD/bin:$PATH"

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

  if cmd_create --no-agent 99 2>/dev/null; then
      echo -e "${RED}FAIL: spawn should fail when trees/main is missing${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: spawn correctly requires init${NC}"

  # Re-initialize for remaining tests
  cmd_init

  echo ""
  # Test 3: Create worktree with fetched title from gh
  echo "Test 3: Create worktree with fetched title from gh"
  cmd_create --no-agent 42

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
  # Test 6: Remove worktree and verify branch deletion (safe delete)
  echo "Test 6: Remove worktree and verify branch deletion"
  cmd_remove 42

  if [ -d "trees/issue-42-test" ]; then
      echo -e "${RED}FAIL: Worktree directory still exists${NC}"
      exit 1
  fi

  # Verify branch was deleted
  if git branch | grep -q "issue-42-test"; then
      echo -e "${RED}FAIL: Branch still exists after removal${NC}"
      exit 1
  fi
  echo -e "${GREEN}PASS: Worktree and branch removed${NC}"

  echo ""
  # Test 7: Prune stale metadata
  echo "Test 7: Prune stale metadata"
  cmd_prune
  echo -e "${GREEN}PASS: Prune completed${NC}"

  echo ""
  # Test 8: Long title truncates to max length (default 10)
  echo "Test 8: Long title truncates to max length"
  cmd_create --no-agent 99
  if [ ! -d "trees/issue-99-test-fail" ]; then
      echo -e "${RED}FAIL: Long suffix not truncated to 10 chars (expected: issue-99-test-fail)${NC}"
      exit 1
  fi
  cmd_remove 99
  echo -e "${GREEN}PASS: Long suffix truncated${NC}"

  echo ""
  # Test 9: Short title preserved
  echo "Test 9: Short title preserved"
  cmd_create --no-agent 88
  if [ ! -d "trees/issue-88-short" ]; then
      echo -e "${RED}FAIL: Short suffix not preserved${NC}"
      exit 1
  fi
  cmd_remove 88
  echo -e "${GREEN}PASS: Short suffix preserved${NC}"

  echo ""
  # Test 10: Word-boundary trimming
  echo "Test 10: Word-boundary trimming"
  cmd_create --no-agent 77
  if [ ! -d "trees/issue-77-very-long" ]; then
      echo -e "${RED}FAIL: Word-boundary trim failed${NC}"
      exit 1
  fi
  cmd_remove 77
  echo -e "${GREEN}PASS: Word-boundary trim works${NC}"

  echo ""
  # Test 11: Env override changes limit
  echo "Test 11: Env override changes limit"
  WORKTREE_SUFFIX_MAX_LENGTH=5 cmd_create --no-agent 66
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
  cmd_create --no-agent 55

  # cd into the linked worktree
  cd trees/issue-55-first

  # Source wt-cli.sh again in the linked worktree context
  source "$TEST_DIR/wt-cli.sh"

  # Try to create another worktree from inside the linked worktree
  # It should create the new worktree under the main repo root, not inside the linked worktree
  cmd_create --no-agent 56

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
  cmd_create --no-agent 100

  # Verify worktree was created
  if [ ! -d "trees/issue-100-test-trunk" ]; then
    echo -e "${RED}FAIL: Worktree not created with metadata-driven branch${NC}"
    exit 1
  fi

  # Verify it's based on trunk branch
  BRANCH_BASE=$(git -C "trees/issue-100-test-trunk" log --oneline -1 2>/dev/null || echo "")
  TRUNK_COMMIT=$(git log trunk --oneline -1 2>/dev/null || echo "")
  if [ -n "$BRANCH_BASE" ] && [ -n "$TRUNK_COMMIT" ] && [[ "$BRANCH_BASE" != "$TRUNK_COMMIT" ]]; then
    echo -e "${RED}FAIL: Worktree not based on trunk branch${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: Metadata-driven default branch works${NC}"

  # Cleanup test repo 2
  cd /
  rm -rf "$TEST_DIR2"

  # Test 14: wt init installs pre-commit hook
  echo ""
  echo "Test 14: wt init installs pre-commit hook"

  TEST_DIR3=$(mktemp -d)
  cd "$TEST_DIR3"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Create scripts/pre-commit
  mkdir -p scripts
  cat > scripts/pre-commit <<'EOF'
#!/usr/bin/env bash
echo "Pre-commit hook running"
exit 0
EOF
  chmod +x scripts/pre-commit

  # Copy wt-cli.sh
  cp "$WT_CLI" ./wt-cli.sh
  echo "Test CLAUDE.md" > CLAUDE.md

  # Source the library
  source ./wt-cli.sh

  # Run init (should install hook)
  cmd_init

  # Verify hook was installed in main worktree
  HOOKS_DIR=$(git -C trees/main rev-parse --git-path hooks)
  if [ ! -L "$HOOKS_DIR/pre-commit" ]; then
    echo -e "${RED}FAIL: pre-commit hook not installed in wt init${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: wt init installs pre-commit hook${NC}"

  cd /
  rm -rf "$TEST_DIR3"

  # Test 15: wt spawn installs pre-commit hook in new worktree
  echo ""
  echo "Test 15: wt spawn installs pre-commit hook in worktree"

  TEST_DIR4=$(mktemp -d)
  cd "$TEST_DIR4"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Create scripts/pre-commit
  mkdir -p scripts
  cat > scripts/pre-commit <<'EOF'
#!/usr/bin/env bash
echo "Pre-commit hook running"
exit 0
EOF
  chmod +x scripts/pre-commit

  # Copy wt-cli.sh
  cp "$WT_CLI" ./wt-cli.sh
  echo "Test CLAUDE.md" > CLAUDE.md

  # Source the library
  source ./wt-cli.sh

  # Initialize first
  cmd_init

  # Create worktree (should install hook)
  cmd_create --no-agent 200

  # Verify hook was installed in the new worktree
  HOOKS_DIR=$(git -C trees/issue-200-test-hook rev-parse --git-path hooks)
  if [ ! -L "$HOOKS_DIR/pre-commit" ]; then
    echo -e "${RED}FAIL: pre-commit hook not installed in wt spawn${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: wt spawn installs pre-commit hook${NC}"

  cd /
  rm -rf "$TEST_DIR4"

  # Back to original test repo for branch deletion tests
  cd "$TEST_DIR"

  # Test 16: Force delete unmerged branch
  echo ""
  echo "Test 16: Force delete unmerged branch with -D flag"

  # Create a worktree with an unmerged commit
  cmd_create --no-agent 210

  # Create an unmerged commit in the worktree
  cd "trees/issue-210-unmerged"
  echo "unmerged content" > unmerged.txt
  git add unmerged.txt
  git commit -m "Unmerged commit"
  cd "$TEST_DIR"

  # Try force delete with -D flag
  cmd_remove -D 210

  # Verify worktree was removed
  if [ -d "trees/issue-210-unmerged" ]; then
      echo -e "${RED}FAIL: Worktree still exists after force removal${NC}"
      exit 1
  fi

  # Verify branch was force-deleted
  if git branch | grep -q "issue-210-unmerged"; then
      echo -e "${RED}FAIL: Branch still exists after force removal${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: Force delete removed unmerged branch${NC}"

  # Test 17: Force delete with --force flag (alternative syntax)
  echo ""
  echo "Test 17: Force delete with --force flag"

  # Create another worktree with an unmerged commit
  cmd_create --no-agent 211

  # Create an unmerged commit
  cd "trees/issue-211-force-test"
  echo "force test content" > force.txt
  git add force.txt
  git commit -m "Force test commit"
  cd "$TEST_DIR"

  # Try force delete with --force flag
  cmd_remove --force 211

  # Verify worktree was removed
  if [ -d "trees/issue-211-force-test" ]; then
      echo -e "${RED}FAIL: Worktree still exists after --force removal${NC}"
      exit 1
  fi

  # Verify branch was force-deleted
  if git branch | grep -q "issue-211-force-test"; then
      echo -e "${RED}FAIL: Branch still exists after --force removal${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: --force flag works for branch deletion${NC}"

  # Test 18: wt spawn with --yolo --no-agent creates worktree
  echo ""
  echo "Test 18: wt spawn with --yolo --no-agent creates worktree"

  TEST_DIR5=$(mktemp -d)
  cd "$TEST_DIR5"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Copy wt-cli.sh
  cp "$WT_CLI" ./wt-cli.sh
  echo "Test CLAUDE.md" > CLAUDE.md

  # Source the library
  source ./wt-cli.sh

  # Initialize first
  cmd_init

  # Create worktree with --yolo --no-agent (should create worktree without invoking Claude)
  cmd_create --yolo --no-agent 300

  # Verify worktree was created
  if [ ! -d "trees/issue-300-test-yolo" ]; then
    echo -e "${RED}FAIL: Worktree not created with --yolo --no-agent${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: --yolo --no-agent creates worktree${NC}"

  cd /
  rm -rf "$TEST_DIR5"

  # Test 19: Flag after issue number regression test
  echo ""
  echo "Test 19: Flag after issue number (--no-agent <issue> --yolo)"

  TEST_DIR6=$(mktemp -d)
  cd "$TEST_DIR6"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Copy wt-cli.sh
  cp "$WT_CLI" ./wt-cli.sh
  echo "Test CLAUDE.md" > CLAUDE.md

  # Source the library
  source ./wt-cli.sh

  # Initialize first
  cmd_init

  # Create worktree with --no-agent --yolo <issue>
  # This test verifies flags work in any position
  cmd_create --no-agent 301 --yolo

  # Verify worktree was created with correct name
  if [ ! -d "trees/issue-301-test-after" ]; then
    echo -e "${RED}FAIL: Worktree not created with correct name (expected: issue-301-test-after)${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: Flag after issue number handled correctly${NC}"

  cd /
  rm -rf "$TEST_DIR6"

  # Test 20: Passing description argument should fail with clear error
  echo ""
  echo "Test 20: Passing description argument should fail with error"

  TEST_DIR7=$(mktemp -d)
  cd "$TEST_DIR7"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Copy wt-cli.sh
  cp "$WT_CLI" ./wt-cli.sh
  echo "Test CLAUDE.md" > CLAUDE.md

  # Source the library
  source ./wt-cli.sh

  # Initialize first
  cmd_init

  # Try to create worktree with description (should fail)
  if cmd_create --no-agent 350 custom-desc 2>/dev/null; then
    echo -e "${RED}FAIL: Should have rejected description argument${NC}"
    exit 1
  fi

  # Verify no worktree was created
  if [ -d "trees/issue-350-custom-desc" ] || [ -d "trees/issue-350"* ]; then
    echo -e "${RED}FAIL: Worktree should not have been created${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: Description argument correctly rejected${NC}"

  cd /
  rm -rf "$TEST_DIR7"

  # Cleanup original test repo
  cd /
  rm -rf "$TEST_DIR"

  echo ""
  echo -e "${GREEN}=== All tests passed ===${NC}"
)
