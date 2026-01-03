#!/usr/bin/env bash
# Test for cross-project wt shell function
# Verifies wt spawn works from any directory, including linked worktrees

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WT_CLI="$PROJECT_ROOT/scripts/wt-cli.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=== Cross-Project wt Function Test ==="

# Test 1: Missing AGENTIZE_HOME produces error
echo ""
echo "Test 1: Missing AGENTIZE_HOME produces error"
(
  unset AGENTIZE_HOME
  if source "$WT_CLI" 2>/dev/null && wt spawn 42 2>/dev/null; then
    echo -e "${RED}FAIL: Should error when AGENTIZE_HOME is missing${NC}"
    exit 1
  fi
  echo -e "${GREEN}PASS: Errors correctly on missing AGENTIZE_HOME${NC}"
) || echo -e "${GREEN}PASS: Errors correctly on missing AGENTIZE_HOME${NC}"

# Test 2: Invalid AGENTIZE_HOME produces error
echo ""
echo "Test 2: Invalid AGENTIZE_HOME produces error"
(
  export AGENTIZE_HOME="/nonexistent/path"
  if source "$WT_CLI" 2>/dev/null && wt spawn 42 2>/dev/null; then
    echo -e "${RED}FAIL: Should error when AGENTIZE_HOME is invalid${NC}"
    exit 1
  fi
  echo -e "${GREEN}PASS: Errors correctly on invalid AGENTIZE_HOME${NC}"
) || echo -e "${GREEN}PASS: Errors correctly on invalid AGENTIZE_HOME${NC}"

# Test 3: wt init creates trees/main worktree
echo ""
echo "Test 3: wt init creates trees/main worktree"

(
  # Unset all git environment variables
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  unset GIT_INDEX_VERSION GIT_COMMON_DIR

  # Create temporary agentize repo
  TEST_AGENTIZE=$(mktemp -d)
  echo "Test agentize repo: $TEST_AGENTIZE"

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
# Stub gh command for testing
case "$1" in
  issue)
    if [ "$2" = "view" ]; then
      issue_no="$3"
      case "$issue_no" in
        42) echo '{"title":"Test cross"}' ;;
        50) echo '{"title":"First"}' ;;
        51) echo '{"title":"Second"}' ;;
        *) exit 1 ;;
      esac
    fi
    ;;
esac
GHSTUB
    chmod +x bin/gh

    # Copy scripts
    mkdir -p scripts
    cp "$WT_CLI" scripts/
    chmod +x scripts/wt-cli.sh
  )

  # Test wt init
  (
    export AGENTIZE_HOME="$TEST_AGENTIZE"
    export PATH="$TEST_AGENTIZE/bin:$PATH"
    cd "$TEST_AGENTIZE"

    # Source wt functions
    source scripts/wt-cli.sh

    # Run init
    wt init

    # Verify trees/main created
    if [ ! -d "$TEST_AGENTIZE/trees/main" ]; then
      echo -e "${RED}FAIL: wt init did not create trees/main${NC}"
      exit 1
    fi

    echo -e "${GREEN}PASS: wt init creates trees/main${NC}"
  )

  # Cleanup
  rm -rf "$TEST_AGENTIZE"
)

# Test 4: wt spawn creates worktree in correct location (cross-project)
echo ""
echo "Test 4: wt spawn creates worktree in correct location"

# Run in subshell with unset git environment variables
(
  # Unset all git environment variables to ensure clean test environment
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  unset GIT_INDEX_VERSION GIT_COMMON_DIR

  # Create temporary agentize repo and another project
  TEST_AGENTIZE=$(mktemp -d)
  TEST_PROJECT=$(mktemp -d)

  echo "Test agentize repo: $TEST_AGENTIZE"
  echo "Test project: $TEST_PROJECT"

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
# Stub gh command for testing
case "$1" in
  issue)
    if [ "$2" = "view" ]; then
      issue_no="$3"
      case "$issue_no" in
        42) echo '{"title":"Test cross"}' ;;
        50) echo '{"title":"First"}' ;;
        51) echo '{"title":"Second"}' ;;
        *) exit 1 ;;
      esac
    fi
    ;;
esac
GHSTUB
    chmod +x bin/gh

    # Copy scripts
    mkdir -p scripts
    cp "$PROJECT_ROOT/scripts/worktree.sh" scripts/ 2>/dev/null || true
    cp "$WT_CLI" scripts/
    chmod +x scripts/wt-cli.sh
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
    source "$TEST_AGENTIZE/scripts/wt-cli.sh"

    # Initialize first
    wt init

    # Create worktree using wt spawn
    wt spawn --no-agent 42

    # Verify worktree created in agentize repo, not current project
    if [ ! -d "$TEST_AGENTIZE/trees/issue-42-test-cross" ]; then
      echo -e "${RED}FAIL: Worktree not created in AGENTIZE_HOME${NC}"
      exit 1
    fi

    if [ -d "$TEST_PROJECT/trees/issue-42-test-cross" ]; then
      echo -e "${RED}FAIL: Worktree incorrectly created in current project${NC}"
      exit 1
    fi

    echo -e "${GREEN}PASS: Worktree created in correct location (AGENTIZE_HOME)${NC}"

    # Test wt list
    if ! wt list | grep -q "issue-42-test-cross"; then
      echo -e "${RED}FAIL: wt list does not show worktree${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: wt list works from different directory${NC}"

    # Test wt remove
    wt remove 42
    if [ -d "$TEST_AGENTIZE/trees/issue-42-test-cross" ]; then
      echo -e "${RED}FAIL: wt remove did not remove worktree${NC}"
      exit 1
    fi
    echo -e "${GREEN}PASS: wt remove works from different directory${NC}"
  )

  # Cleanup
  rm -rf "$TEST_AGENTIZE" "$TEST_PROJECT"
)

# Test 5: wt spawn from linked worktree creates under main repo
echo ""
echo "Test 5: wt spawn from linked worktree creates under main repo"
(
  # Unset all git environment variables to ensure clean test environment
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  unset GIT_INDEX_VERSION GIT_COMMON_DIR

  # Create temporary agentize repo
  TEST_AGENTIZE=$(mktemp -d)
  echo "Test agentize repo: $TEST_AGENTIZE"

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
# Stub gh command for testing
case "$1" in
  issue)
    if [ "$2" = "view" ]; then
      issue_no="$3"
      case "$issue_no" in
        42) echo '{"title":"Test cross"}' ;;
        50) echo '{"title":"First"}' ;;
        51) echo '{"title":"Second"}' ;;
        *) exit 1 ;;
      esac
    fi
    ;;
esac
GHSTUB
    chmod +x bin/gh

    # Copy scripts
    mkdir -p scripts
    cp "$WT_CLI" scripts/
    chmod +x scripts/wt-cli.sh
  )

  # Create first worktree
  (
    export AGENTIZE_HOME="$TEST_AGENTIZE"
    export PATH="$TEST_AGENTIZE/bin:$PATH"
    cd "$TEST_AGENTIZE"
    source scripts/wt-cli.sh

    # Initialize first
    wt init

    wt spawn --no-agent 50

    # Now cd into the linked worktree and create another worktree
    cd trees/issue-50-first

    # Source again in linked worktree context
    source "$TEST_AGENTIZE/scripts/wt-cli.sh"

    # Create another worktree from inside the linked worktree
    wt spawn --no-agent 51

    # Verify the new worktree is created under AGENTIZE_HOME, not inside the linked worktree
    if [ ! -d "$TEST_AGENTIZE/trees/issue-51-second" ]; then
      echo -e "${RED}FAIL: Worktree not created under main repo root${NC}"
      exit 1
    fi

    # Verify it's NOT created inside the linked worktree
    if [ -d "trees/issue-51-second" ]; then
      echo -e "${RED}FAIL: Worktree incorrectly created inside linked worktree${NC}"
      exit 1
    fi

    echo -e "${GREEN}PASS: wt spawn from linked worktree creates under AGENTIZE_HOME${NC}"
  )

  # Cleanup
  rm -rf "$TEST_AGENTIZE"
)

echo ""
echo -e "${GREEN}=== All cross-project tests passed ===${NC}"
