#!/usr/bin/env bash
# Test: lol upgrade runs make setup after successful git pull

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol upgrade runs make setup after successful git pull"

# Create temp directory for test environment
TMP_DIR=$(make_temp_dir "test-lol-upgrade")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create mock AGENTIZE_HOME with git repo
MOCK_AGENTIZE_HOME="$TMP_DIR/agentize"
mkdir -p "$MOCK_AGENTIZE_HOME"
git -C "$MOCK_AGENTIZE_HOME" init -q
git -C "$MOCK_AGENTIZE_HOME" config user.email "test@test.com"
git -C "$MOCK_AGENTIZE_HOME" config user.name "Test"
touch "$MOCK_AGENTIZE_HOME/README.md"
git -C "$MOCK_AGENTIZE_HOME" add .
git -C "$MOCK_AGENTIZE_HOME" commit -q -m "Initial commit"

# Create a simple Makefile with setup target that creates a marker file
cat > "$MOCK_AGENTIZE_HOME/Makefile" << 'MAKEFILE'
.PHONY: setup
setup:
	@touch setup-was-called.marker
	@echo "Setup completed"
MAKEFILE

# Commit Makefile to avoid dirty-tree guard
git -C "$MOCK_AGENTIZE_HOME" add Makefile
git -C "$MOCK_AGENTIZE_HOME" commit -q -m "Add Makefile"

# Set origin to self (so git pull works)
git -C "$MOCK_AGENTIZE_HOME" remote add origin "$MOCK_AGENTIZE_HOME"
git -C "$MOCK_AGENTIZE_HOME" fetch -q origin 2>/dev/null || true

# Create origin/main branch for pull to succeed
git -C "$MOCK_AGENTIZE_HOME" branch -M main
git -C "$MOCK_AGENTIZE_HOME" symbolic-ref refs/remotes/origin/HEAD refs/heads/main 2>/dev/null || true

# Set up environment
export AGENTIZE_HOME="$MOCK_AGENTIZE_HOME"
source "$LOL_CLI"

# Test 1: Verify make setup is called after git pull
test_info "Test 1: make setup is called after successful git pull"

# Remove any existing marker
rm -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker"

# Run upgrade
output=$(lol upgrade 2>&1) || true

# Check if make setup was called (marker file should exist)
if [ ! -f "$MOCK_AGENTIZE_HOME/setup-was-called.marker" ]; then
    echo "Output:"
    echo "$output"
    test_fail "make setup was not executed - marker file missing"
fi

# Test 2: Verify output mentions setup completion
test_info "Test 2: output mentions upgrade success"

if ! echo "$output" | grep -qi "upgrade\|success"; then
    echo "Output:"
    echo "$output"
    test_fail "Output should mention successful upgrade"
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

test_pass "lol upgrade correctly runs make setup and optional plugin update"
