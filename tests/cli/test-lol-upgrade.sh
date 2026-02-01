#!/usr/bin/env bash
# Test: lol upgrade switches to default branch unless --keep-branch is set

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol upgrade switches to default branch unless --keep-branch is set"

# Create temp directory for test environment
TMP_DIR=$(make_temp_dir "test-lol-upgrade")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create mock remote repo
REMOTE_REPO="$TMP_DIR/remote.git"
git init -q --bare "$REMOTE_REPO"

# Create mock AGENTIZE_HOME with git repo
MOCK_AGENTIZE_HOME="$TMP_DIR/agentize"
mkdir -p "$MOCK_AGENTIZE_HOME"
git -C "$MOCK_AGENTIZE_HOME" init -q
git -C "$MOCK_AGENTIZE_HOME" config user.email "test@test.com"
git -C "$MOCK_AGENTIZE_HOME" config user.name "Test"

# Create a simple Makefile with setup target that creates a marker file
cat > "$MOCK_AGENTIZE_HOME/Makefile" << 'MAKEFILE'
.PHONY: setup
setup:
	@touch setup-was-called.marker
	@echo "Setup completed"
MAKEFILE

# Initial commit
cat > "$MOCK_AGENTIZE_HOME/README.md" << 'EOF_README'
# Mock Repo
EOF_README
git -C "$MOCK_AGENTIZE_HOME" add .
git -C "$MOCK_AGENTIZE_HOME" commit -q -m "Initial commit"

# Set main branch and push to origin
# Ensure origin remote exists for upgrade pulls

git -C "$MOCK_AGENTIZE_HOME" branch -M main
git -C "$MOCK_AGENTIZE_HOME" remote add origin "$REMOTE_REPO"
git -C "$MOCK_AGENTIZE_HOME" push -q -u origin main

# Create a feature branch on origin for --keep-branch testing

git -C "$MOCK_AGENTIZE_HOME" checkout -q -b feature/test-branch
cat > "$MOCK_AGENTIZE_HOME/feature.txt" << 'EOF_FEATURE'
feature branch content
EOF_FEATURE
git -C "$MOCK_AGENTIZE_HOME" add feature.txt
git -C "$MOCK_AGENTIZE_HOME" commit -q -m "Add feature branch"
git -C "$MOCK_AGENTIZE_HOME" push -q -u origin feature/test-branch

# Return to main

git -C "$MOCK_AGENTIZE_HOME" checkout -q main

# Ensure origin/HEAD resolves to main for default branch detection

git -C "$MOCK_AGENTIZE_HOME" fetch -q origin
git -C "$MOCK_AGENTIZE_HOME" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main 2>/dev/null || true

# Set up environment
export AGENTIZE_HOME="$MOCK_AGENTIZE_HOME"
source "$LOL_CLI"

# Test 1: Verify default upgrade switches to main

test_info "Test 1: default upgrade switches to default branch"

git -C "$MOCK_AGENTIZE_HOME" checkout -q feature/test-branch
rm -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker"

output=$(lol upgrade 2>&1) || true

if [ ! -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker" ]; then
    echo "Output:"
    echo "$output"
    test_fail "make setup was not executed - marker file missing"
fi

current_branch=$(git -C "$MOCK_AGENTIZE_HOME" rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "main" ]; then
    echo "Output:"
    echo "$output"
    test_fail "Expected to be on main after default upgrade, got '$current_branch'"
fi

if ! echo "$output" | grep -qi "default branch"; then
    echo "Output:"
    echo "$output"
    test_fail "Output should mention default branch switching"
fi

# Test 2: Verify --keep-branch preserves current branch

test_info "Test 2: --keep-branch stays on current branch"

git -C "$MOCK_AGENTIZE_HOME" checkout -q feature/test-branch
rm -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker"

output=$(lol upgrade --keep-branch 2>&1) || true

if [ ! -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker" ]; then
    echo "Output:"
    echo "$output"
    test_fail "make setup was not executed with --keep-branch"
fi

current_branch=$(git -C "$MOCK_AGENTIZE_HOME" rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "feature/test-branch" ]; then
    echo "Output:"
    echo "$output"
    test_fail "Expected to remain on feature/test-branch with --keep-branch"
fi

if ! echo "$output" | grep -qi "keep.*branch\|keeping"; then
    echo "Output:"
    echo "$output"
    test_fail "Output should mention keeping current branch"
fi

# Test 3: Verify shell reload instructions are displayed

test_info "Test 3: shell reload instructions are displayed"

if ! echo "$output" | grep -q "reload\|exec"; then
    echo "Output:"
    echo "$output"
    test_fail "Output should include shell reload instructions"
fi

# Test 4: Verify claude plugin update is called when claude is available

test_info "Test 4: claude plugin update is called when claude is available"

# Create a mock claude binary that logs its arguments
MOCK_BIN_DIR="$TMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN_DIR"
CLAUDE_LOG="$TMP_DIR/claude-calls.log"
cat > "$MOCK_BIN_DIR/claude" << 'MOCKEOF'
#!/usr/bin/env bash
echo "$@" >> "$(dirname "$0")/../claude-calls.log"
exit 0
MOCKEOF
chmod +x "$MOCK_BIN_DIR/claude"

# Prepend mock bin to PATH so `command -v claude` finds our mock
export PATH="$MOCK_BIN_DIR:$PATH"

# Remove stale marker and re-run upgrade
rm -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker"
rm -f "$CLAUDE_LOG"

git -C "$MOCK_AGENTIZE_HOME" checkout -q main

output=$(_lol_cmd_upgrade 2>&1) || true

# Check that claude was called with plugin update arguments
if [ ! -f "$CLAUDE_LOG" ]; then
    echo "Output:"
    echo "$output"
    test_fail "claude was not called at all during upgrade"
fi

if ! grep -q "plugin.*update\|plugin.*marketplace" "$CLAUDE_LOG"; then
    echo "Claude calls:"
    cat "$CLAUDE_LOG"
    test_fail "claude was not called with plugin update arguments"
fi

# Test 5: Verify upgrade succeeds when claude is NOT available

test_info "Test 5: upgrade succeeds when claude is not available"

# Remove mock claude from PATH
export PATH="${PATH#$MOCK_BIN_DIR:}"

# Remove stale marker
rm -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker"

output=$(_lol_cmd_upgrade 2>&1) || true

# Upgrade should still succeed (make setup marker should exist)
if [ ! -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker" ]; then
    echo "Output:"
    echo "$output"
    test_fail "upgrade failed when claude is not available"
fi

test_pass "lol upgrade handles branch switching and setup workflow"
