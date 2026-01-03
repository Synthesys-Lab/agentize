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

  # Create gh stub that validates issue existence
  mkdir -p bin
  cat > bin/gh <<'GHSTUB'
#!/usr/bin/env bash
# Stub gh command for testing
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  issue_no="$3"
  # Valid issue numbers return exit code 0, invalid ones return 1
  case "$issue_no" in
    42|55|56|100|200|210|211|300|301|350) exit 0 ;;
    *) exit 1 ;;
  esac
fi
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
  # Test 3: Create worktree with issue validation
  echo "Test 3: Create worktree with issue validation"
  cmd_create --no-agent 42

  if [ ! -d "trees/issue-42" ]; then
      echo -e "${RED}FAIL: Worktree directory not created (expected: issue-42)${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: Worktree created${NC}"

  echo ""
  # Test 4: List worktrees
  echo "Test 4: List worktrees"
  OUTPUT=$(cmd_list)
  if [[ ! "$OUTPUT" =~ "issue-42" ]]; then
      echo -e "${RED}FAIL: Worktree not listed${NC}"
      exit 1
  fi
  echo -e "${GREEN}PASS: Worktree listed${NC}"

  echo ""
  # Test 5: Verify branch exists
  echo "Test 5: Verify branch exists"
  if ! git branch | grep -q "issue-42"; then
      echo -e "${RED}FAIL: Branch not created${NC}"
      exit 1
  fi
  echo -e "${GREEN}PASS: Branch created${NC}"

  echo ""
  # Test 6: Remove worktree and verify branch deletion (safe delete)
  echo "Test 6: Remove worktree and verify branch deletion"
  cmd_remove 42

  if [ -d "trees/issue-42" ]; then
      echo -e "${RED}FAIL: Worktree directory still exists${NC}"
      exit 1
  fi

  # Verify branch was deleted
  if git branch | grep -q "issue-42"; then
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
  # Test 8: Invalid issue number fails validation
  echo "Test 8: Invalid issue number fails validation"
  if cmd_create --no-agent 999 2>/dev/null; then
      echo -e "${RED}FAIL: Should fail for invalid issue number${NC}"
      exit 1
  fi
  echo -e "${GREEN}PASS: Invalid issue validation works${NC}"

  echo ""
  # Test 9: Legacy worktree removal (issue-{N}-{slug} format)
  echo "Test 9: Legacy worktree removal"
  # Manually create a legacy-named worktree
  git worktree add trees/issue-88-legacy-name -b issue-88-legacy-name

  # Verify it was created
  if [ ! -d "trees/issue-88-legacy-name" ]; then
      echo -e "${RED}FAIL: Failed to create legacy worktree for testing${NC}"
      exit 1
  fi

  # Remove using cmd_remove with issue number
  cmd_remove 88

  # Verify legacy worktree was removed
  if [ -d "trees/issue-88-legacy-name" ]; then
      echo -e "${RED}FAIL: Legacy worktree not removed${NC}"
      exit 1
  fi

  # Verify branch was deleted
  if git branch | grep -q "issue-88-legacy-name"; then
      echo -e "${RED}FAIL: Legacy branch not removed${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: Legacy worktree removal works${NC}"

  echo ""
  # Test 10: Linked worktree regression - create worktree from linked worktree
  echo "Test 10: Linked worktree - create worktree from linked worktree"

  # Create first worktree
  cmd_create --no-agent 55

  # cd into the linked worktree
  cd trees/issue-55

  # Source wt-cli.sh again in the linked worktree context
  source "$TEST_DIR/wt-cli.sh"

  # Try to create another worktree from inside the linked worktree
  # It should create the new worktree under the main repo root, not inside the linked worktree
  cmd_create --no-agent 56

  # Verify the new worktree is created under main repo root
  if [ ! -d "$TEST_DIR/trees/issue-56" ]; then
      echo -e "${RED}FAIL: Worktree not created under main repo root${NC}"
      exit 1
  fi

  # Verify it's NOT created inside the linked worktree
  if [ -d "trees/issue-56" ]; then
      echo -e "${RED}FAIL: Worktree incorrectly created inside linked worktree${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: Linked worktree creates under main repo root${NC}"

  # Cleanup - go back to main repo
  cd "$TEST_DIR"
  cmd_remove 55
  cmd_remove 56

  # Test 11: Metadata-driven default branch selection
  echo ""
  echo "Test 11: Metadata-driven default branch (trunk via .agentize.yaml)"

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

  # Copy wt-cli.sh and gh stub
  cp "$WT_CLI" ./wt-cli.sh
  echo "Test CLAUDE.md" > CLAUDE.md
  mkdir -p bin
  cp "$TEST_DIR/bin/gh" bin/gh
  export PATH="$PWD/bin:$PATH"

  # Source the library
  source ./wt-cli.sh

  # Initialize first
  cmd_init

  # Create worktree (should use trunk, not main/master)
  cmd_create --no-agent 100

  # Verify worktree was created
  if [ ! -d "trees/issue-100" ]; then
    echo -e "${RED}FAIL: Worktree not created with metadata-driven branch${NC}"
    exit 1
  fi

  # Verify it's based on trunk branch
  BRANCH_BASE=$(git -C "trees/issue-100" log --oneline -1 2>/dev/null || echo "")
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

  # Test 13: wt spawn installs pre-commit hook in new worktree
  echo ""
  echo "Test 13: wt spawn installs pre-commit hook in worktree"

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

  # Copy wt-cli.sh and gh stub
  cp "$WT_CLI" ./wt-cli.sh
  echo "Test CLAUDE.md" > CLAUDE.md
  mkdir -p bin
  cp "$TEST_DIR/bin/gh" bin/gh
  export PATH="$PWD/bin:$PATH"

  # Source the library
  source ./wt-cli.sh

  # Initialize first
  cmd_init

  # Create worktree (should install hook)
  cmd_create --no-agent 200

  # Verify hook was installed in the new worktree
  HOOKS_DIR=$(git -C trees/issue-200 rev-parse --git-path hooks)
  if [ ! -L "$HOOKS_DIR/pre-commit" ]; then
    echo -e "${RED}FAIL: pre-commit hook not installed in wt spawn${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: wt spawn installs pre-commit hook${NC}"

  cd /
  rm -rf "$TEST_DIR4"

  # Back to original test repo for branch deletion tests
  cd "$TEST_DIR"

  # Test 14: Force delete unmerged branch
  echo ""
  echo "Test 14: Force delete unmerged branch with -D flag"

  # Create a worktree with an unmerged commit
  cmd_create --no-agent 210

  # Create an unmerged commit in the worktree
  cd "trees/issue-210"
  echo "unmerged content" > unmerged.txt
  git add unmerged.txt
  git commit -m "Unmerged commit"
  cd "$TEST_DIR"

  # Try force delete with -D flag
  cmd_remove -D 210

  # Verify worktree was removed
  if [ -d "trees/issue-210" ]; then
      echo -e "${RED}FAIL: Worktree still exists after force removal${NC}"
      exit 1
  fi

  # Verify branch was force-deleted
  if git branch | grep -q "issue-210"; then
      echo -e "${RED}FAIL: Branch still exists after force removal${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: Force delete removed unmerged branch${NC}"

  # Test 15: Force delete with --force flag (alternative syntax)
  echo ""
  echo "Test 15: Force delete with --force flag"

  # Create another worktree with an unmerged commit
  cmd_create --no-agent 211

  # Create an unmerged commit
  cd "trees/issue-211"
  echo "force test content" > force.txt
  git add force.txt
  git commit -m "Force test commit"
  cd "$TEST_DIR"

  # Try force delete with --force flag
  cmd_remove --force 211

  # Verify worktree was removed
  if [ -d "trees/issue-211" ]; then
      echo -e "${RED}FAIL: Worktree still exists after --force removal${NC}"
      exit 1
  fi

  # Verify branch was force-deleted
  if git branch | grep -q "issue-211"; then
      echo -e "${RED}FAIL: Branch still exists after --force removal${NC}"
      exit 1
  fi

  echo -e "${GREEN}PASS: --force flag works for branch deletion${NC}"

  # Test 16: wt spawn with --yolo --no-agent creates worktree
  echo ""
  echo "Test 16: wt spawn with --yolo --no-agent creates worktree"

  TEST_DIR5=$(mktemp -d)
  cd "$TEST_DIR5"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Copy wt-cli.sh and gh stub
  cp "$WT_CLI" ./wt-cli.sh
  echo "Test CLAUDE.md" > CLAUDE.md
  mkdir -p bin
  cp "$TEST_DIR/bin/gh" bin/gh
  export PATH="$PWD/bin:$PATH"

  # Source the library
  source ./wt-cli.sh

  # Initialize first
  cmd_init

  # Create worktree with --yolo --no-agent (should create worktree without invoking Claude)
  cmd_create --yolo --no-agent 300

  # Verify worktree was created
  if [ ! -d "trees/issue-300" ]; then
    echo -e "${RED}FAIL: Worktree not created with --yolo --no-agent${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: --yolo --no-agent creates worktree${NC}"

  cd /
  rm -rf "$TEST_DIR5"

  # Test 17: Flag after issue number regression test
  echo ""
  echo "Test 17: Flag after issue number (--no-agent <issue> --yolo)"

  TEST_DIR6=$(mktemp -d)
  cd "$TEST_DIR6"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit"

  # Copy wt-cli.sh and gh stub
  cp "$WT_CLI" ./wt-cli.sh
  echo "Test CLAUDE.md" > CLAUDE.md
  mkdir -p bin
  cp "$TEST_DIR/bin/gh" bin/gh
  export PATH="$PWD/bin:$PATH"

  # Source the library
  source ./wt-cli.sh

  # Initialize first
  cmd_init

  # Create worktree with --no-agent --yolo <issue>
  # This test verifies flags work in any position
  cmd_create --no-agent 301 --yolo

  # Verify worktree was created with correct name
  if [ ! -d "trees/issue-301" ]; then
    echo -e "${RED}FAIL: Worktree not created with correct name (expected: issue-301)${NC}"
    exit 1
  fi

  echo -e "${GREEN}PASS: Flag after issue number handled correctly${NC}"

  cd /
  rm -rf "$TEST_DIR6"

  # Cleanup original test repo
  cd /
  rm -rf "$TEST_DIR"

  echo ""
  echo -e "${GREEN}=== All tests passed ===${NC}"
)
