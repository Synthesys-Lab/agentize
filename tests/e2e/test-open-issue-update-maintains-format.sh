#!/usr/bin/env bash
# Test: --update maintains [plan][tag] format

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

source "$TESTS_DIR/helpers-gh-mock.sh"

test_info "--update maintains [plan][tag] format"

TMP_DIR=$(make_temp_dir "open-issue-update-format")
GH_CAPTURE_FILE="$TMP_DIR/gh-capture.txt"
export GH_CAPTURE_FILE

# Setup gh mock
setup_gh_mock_open_issue "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Test update maintains format
"$TMP_DIR/gh" issue edit 42 --title "[plan][refactor]: Simplified implementation"
CAPTURED_TITLE=$(grep "TITLE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)

if [[ "$CAPTURED_TITLE" == "[plan][refactor]:"* ]]; then
    cleanup_dir "$TMP_DIR"
    test_pass "--update maintains [plan] prefix"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Expected title starting with '[plan][refactor]:', got '$CAPTURED_TITLE'"
fi
