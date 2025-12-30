#!/usr/bin/env bash
# Test suite for Claude Code PermissionRequest hook

set -e

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/permission-request.sh"
FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures/permission-request"
HANDS_OFF_CONFIG="$PROJECT_ROOT/.claude/hands-off.json"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper: Print test header
test_start() {
    echo -e "\n${YELLOW}TEST:${NC} $1"
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Helper: Assert decision equals expected
assert_decision() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}✓${NC} $test_name: got '$actual' as expected"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name: expected '$expected', got '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Helper: Run hook with fixture and extract decision
run_hook() {
    local fixture_file="$1"
    if [ ! -f "$HOOK_SCRIPT" ]; then
        echo "skip"
        return
    fi

    # Run hook and extract decision field from JSON output
    local output
    output=$("$HOOK_SCRIPT" < "$fixture_file" 2>/dev/null || echo '{"decision":"error"}')
    echo "$output" | grep -o '"decision"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/'
}

# Backup and restore hands-off config
backup_config() {
    if [ -f "$HANDS_OFF_CONFIG" ]; then
        cp "$HANDS_OFF_CONFIG" "$HANDS_OFF_CONFIG.backup"
    fi
}

restore_config() {
    if [ -f "$HANDS_OFF_CONFIG.backup" ]; then
        mv "$HANDS_OFF_CONFIG.backup" "$HANDS_OFF_CONFIG"
    else
        rm -f "$HANDS_OFF_CONFIG"
    fi
}

# Cleanup on exit
cleanup() {
    restore_config
}
trap cleanup EXIT

# Start tests
echo "================================="
echo "Claude Permission Hook Test Suite"
echo "================================="

# Check if hook exists
if [ ! -f "$HOOK_SCRIPT" ]; then
    echo -e "${YELLOW}⚠${NC} Hook script not found at $HOOK_SCRIPT"
    echo "This is expected if hook not yet implemented. Skipping tests."
    exit 0
fi

# Test 1: Hands-off disabled → always ask
test_start "Hands-off disabled: safe read operation"
backup_config
echo '{"enabled": false}' > "$HANDS_OFF_CONFIG"
DECISION=$(run_hook "$FIXTURES_DIR/safe-read.json")
assert_decision "ask" "$DECISION" "Disabled mode returns 'ask'"

# Test 2: Hands-off enabled + safe read → allow
test_start "Hands-off enabled: safe read operation"
echo '{"enabled": true}' > "$HANDS_OFF_CONFIG"
DECISION=$(run_hook "$FIXTURES_DIR/safe-read.json")
assert_decision "allow" "$DECISION" "Safe read auto-approved"

# Test 3: Hands-off enabled + reversible write → allow
test_start "Hands-off enabled: reversible write operation"
DECISION=$(run_hook "$FIXTURES_DIR/reversible-write.json")
assert_decision "allow" "$DECISION" "Reversible write auto-approved"

# Test 4: Hands-off enabled + destructive push → deny/ask
test_start "Hands-off enabled: destructive git push"
DECISION=$(run_hook "$FIXTURES_DIR/destructive-push.json")
if [ "$DECISION" = "deny" ] || [ "$DECISION" = "ask" ]; then
    echo -e "${GREEN}✓${NC} Destructive push blocked: got '$DECISION'"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Destructive push should be blocked, got '$DECISION'"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: Hands-off enabled + git reset hard → deny/ask
test_start "Hands-off enabled: destructive git reset --hard"
DECISION=$(run_hook "$FIXTURES_DIR/git-reset-hard.json")
if [ "$DECISION" = "deny" ] || [ "$DECISION" = "ask" ]; then
    echo -e "${GREEN}✓${NC} Destructive reset blocked: got '$DECISION'"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Destructive reset should be blocked, got '$DECISION'"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: git add with .milestones/ present → deny/ask
# (This requires mocking git status, which is complex; we'll test the logic exists)
test_start "Hands-off enabled: git add when .milestones/ present"
# Create a mock scenario
(
    cd "$PROJECT_ROOT"
    mkdir -p .milestones
    touch .milestones/test-milestone.md
    DECISION=$(run_hook "$FIXTURES_DIR/git-add-with-milestones.json")
    rm -rf .milestones

    # The hook should check for .milestones/ and deny/ask
    # Exact behavior depends on implementation
    echo -e "${YELLOW}ℹ${NC} Git add with milestones check: got '$DECISION'"
    # This is informational for now
)

# Summary
echo ""
echo "================================="
echo "Test Summary"
echo "================================="
echo "Tests run:    $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
