#!/usr/bin/env bash
# Test: Plan issue title format

# Shared test helpers
set -e
SCRIPT_PATH="$0"
if [ -n "${BASH_SOURCE[0]-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
if [ "${SCRIPT_PATH%/*}" = "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="."
else
  SCRIPT_DIR="${SCRIPT_PATH%/*}"
fi
source "$SCRIPT_DIR/../common.sh"

source "$SCRIPT_DIR/../helpers-gh-mock.sh"

test_info "Plan issue title format"

TMP_DIR=$(make_temp_dir "open-issue-plan-format")
GH_CAPTURE_FILE="$TMP_DIR/gh-capture.txt"
export GH_CAPTURE_FILE

# Setup gh mock
setup_gh_mock_open_issue "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Test plan issue title format (no [draft] prefix)
TITLE="[plan][feat]: Add test feature"
"$TMP_DIR/gh" issue create --title "$TITLE" --body "test"
CAPTURED_TITLE=$(grep "TITLE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)

if [ "$CAPTURED_TITLE" = "[plan][feat]: Add test feature" ]; then
    cleanup_dir "$TMP_DIR"
    test_pass "Plan issue title has correct format (no [draft] prefix)"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Expected '[plan][feat]: Add test feature', got '$CAPTURED_TITLE'"
fi
