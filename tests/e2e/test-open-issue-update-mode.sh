#!/usr/bin/env bash
# Test: --update mode uses gh issue edit

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

test_info "--update mode uses gh issue edit"

TMP_DIR=$(make_temp_dir "open-issue-update-mode")
GH_CAPTURE_FILE="$TMP_DIR/gh-capture.txt"
export GH_CAPTURE_FILE

# Setup gh mock
setup_gh_mock_open_issue "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Simulate open-issue --update behavior
"$TMP_DIR/gh" issue edit 42 --title "[plan][feat]: Updated feature title"
OPERATION=$(grep "OPERATION:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)
ISSUE_NUM=$(grep "ISSUE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)

if [ "$OPERATION" = "edit" ] && [ "$ISSUE_NUM" = "42" ]; then
    cleanup_dir "$TMP_DIR"
    test_pass "--update uses gh issue edit with correct issue number"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Expected 'edit' operation on issue 42, got operation='$OPERATION' issue='$ISSUE_NUM'"
fi
