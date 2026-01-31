#!/usr/bin/env bash
# Test: Non-plan issue format (bug report)

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

source "$TESTS_DIR/helpers-gh-mock.sh"

test_info "Non-plan issue format (bug report)"

TMP_DIR=$(make_temp_dir "open-issue-non-plan")
GH_CAPTURE_FILE="$TMP_DIR/gh-capture.txt"
export GH_CAPTURE_FILE

# Setup gh mock
setup_gh_mock_open_issue "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Bug reports have no [plan] or [draft] prefix
TITLE="[bugfix]: Fix authentication error"
"$TMP_DIR/gh" issue create --title "$TITLE" --body "test"
CAPTURED_TITLE=$(grep "TITLE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)

if [ "$CAPTURED_TITLE" = "[bugfix]: Fix authentication error" ]; then
    cleanup_dir "$TMP_DIR"
    test_pass "Non-plan issues have correct format (no [plan] prefix)"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Expected '[bugfix]: Fix authentication error', got '$CAPTURED_TITLE'"
fi
