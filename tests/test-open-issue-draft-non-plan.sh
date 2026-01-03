#!/usr/bin/env bash
# Test: --draft with non-plan issue (bug report)

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/helpers-open-issue.sh"

test_info "--draft with non-plan issue (bug report)"

TMP_DIR=$(make_temp_dir "open-issue-draft-non-plan")
GH_CAPTURE_FILE="$TMP_DIR/gh-capture.txt"
export GH_CAPTURE_FILE

# Setup gh mock
setup_gh_mock_open_issue "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Bug reports should not get [draft] prefix even with --draft flag
TITLE="[bugfix]: Fix authentication error"
"$TMP_DIR/gh" issue create --title "$TITLE" --body "test"
CAPTURED_TITLE=$(grep "TITLE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)

if [ "$CAPTURED_TITLE" = "[bugfix]: Fix authentication error" ]; then
    cleanup_dir "$TMP_DIR"
    test_pass "Non-plan issues don't get [draft] prefix"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Expected '[bugfix]: Fix authentication error', got '$CAPTURED_TITLE'"
fi
