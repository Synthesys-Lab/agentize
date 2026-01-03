#!/usr/bin/env bash
# Test: --update maintains [draft][plan][tag] format

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/helpers-open-issue.sh"

test_info "--update maintains [draft][plan][tag] format"

TMP_DIR=$(make_temp_dir "open-issue-update-format")
GH_CAPTURE_FILE="$TMP_DIR/gh-capture.txt"
export GH_CAPTURE_FILE

# Setup gh mock
setup_gh_mock_open_issue "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Test update maintains format
"$TMP_DIR/gh" issue edit 42 --title "[draft][plan][refactor]: Simplified implementation"
CAPTURED_TITLE=$(grep "TITLE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)

if [[ "$CAPTURED_TITLE" == "[draft][plan][refactor]:"* ]]; then
    cleanup_dir "$TMP_DIR"
    test_pass "--update maintains [draft][plan] prefix"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Expected title starting with '[draft][plan][refactor]:', got '$CAPTURED_TITLE'"
fi
