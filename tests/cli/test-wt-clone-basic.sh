#!/usr/bin/env bash
# Test: wt clone creates bare repo with trees/main

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt clone creates bare repo with trees/main"

WT_CLI="$PROJECT_ROOT/src/cli/wt.sh"

# Create a source repository to clone from
SEED_DIR=$(mktemp -d)
cd "$SEED_DIR"
git init
git config user.email "test@example.com"
git config user.name "Test User"
echo "test content" > README.md
git add README.md
git commit -m "Initial commit"

# Create test directory for clone destination
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# Source wt.sh to get the wt function
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$WT_CLI"

# --------------------------------------------------
# Test 1: wt clone with explicit destination
# --------------------------------------------------
test_info "Test 1: wt clone with explicit destination"

dest_name="myrepo.git"
wt clone "$SEED_DIR" "$dest_name" >/dev/null 2>&1
clone_status=$?

if [ $clone_status -ne 0 ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "wt clone failed with exit code $clone_status"
fi

# Verify bare repo was created
if [ ! -d "$TEST_DIR/$dest_name" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "Destination directory $dest_name was not created"
fi

# Verify it's a bare repo
if [ "$(git -C "$TEST_DIR/$dest_name" rev-parse --is-bare-repository)" != "true" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "Cloned repository is not a bare repo"
fi

# Verify trees/main was created
if [ ! -d "$TEST_DIR/$dest_name/trees/main" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "trees/main was not created in $dest_name"
fi

# Verify README.md exists in trees/main (worktree content)
if [ ! -f "$TEST_DIR/$dest_name/trees/main/README.md" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "README.md not found in trees/main"
fi

# --------------------------------------------------
# Test 2: wt clone infers destination from URL
# --------------------------------------------------
test_info "Test 2: wt clone infers destination from URL"

# Return to TEST_DIR first (clone changes directory)
cd "$TEST_DIR"

# Use a path ending with .git to test inference
wt clone "$SEED_DIR" >/dev/null 2>&1
clone_status=$?

# Expected destination: basename of SEED_DIR + .git
expected_base=$(basename "$SEED_DIR")
expected_dest="${expected_base}.git"

if [ $clone_status -ne 0 ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "wt clone (inferred dest) failed with exit code $clone_status"
fi

if [ ! -d "$TEST_DIR/$expected_dest" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "Inferred destination $expected_dest was not created"
fi

if [ ! -d "$TEST_DIR/$expected_dest/trees/main" ]; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "trees/main was not created in inferred dest $expected_dest"
fi

# --------------------------------------------------
# Test 3: wt clone fails if destination exists
# --------------------------------------------------
test_info "Test 3: wt clone fails if destination exists"

# Return to TEST_DIR first
cd "$TEST_DIR"

mkdir -p "$TEST_DIR/existing.git"
if wt clone "$SEED_DIR" "existing.git" >/dev/null 2>&1; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "wt clone should fail when destination already exists"
fi

# --------------------------------------------------
# Test 4: wt clone fails without URL
# --------------------------------------------------
test_info "Test 4: wt clone fails without URL"

if wt clone 2>/dev/null; then
  rm -rf "$SEED_DIR" "$TEST_DIR"
  test_fail "wt clone should fail when no URL provided"
fi

# --------------------------------------------------
# Cleanup
# --------------------------------------------------
rm -rf "$SEED_DIR" "$TEST_DIR"
test_pass "wt clone creates bare repo with trees/main"
