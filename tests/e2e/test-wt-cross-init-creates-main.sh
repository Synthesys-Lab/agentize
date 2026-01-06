#!/usr/bin/env bash
# Test: wt init creates trees/main worktree

source "$(dirname "$0")/../common.sh"

test_info "wt init creates trees/main worktree"

# Source wt functions from project root
source "$PROJECT_ROOT/src/cli/wt.sh"

# Unset all git environment variables
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

# Test wt init (wt functions already sourced via session-init.sh)
export AGENTIZE_HOME="$TEST_AGENTIZE"
export PATH="$TEST_AGENTIZE/bin:$PATH"

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
