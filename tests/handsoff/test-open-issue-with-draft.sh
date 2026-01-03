#!/usr/bin/env bash
# Test: With --draft flag

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-open-issue.sh"

test_info "With --draft flag"

TMP_DIR=$(make_temp_dir "open-issue-with-draft")
GH_CAPTURE_FILE="$TMP_DIR/gh-capture.txt"
export GH_CAPTURE_FILE

# Setup gh mock
setup_gh_mock_open_issue "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Test with --draft flag
TITLE="[draft][plan][feat]: Add test feature"
"$TMP_DIR/gh" issue create --title "$TITLE" --body "test"
CAPTURED_TITLE=$(grep "TITLE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)

if [ "$CAPTURED_TITLE" = "[draft][plan][feat]: Add test feature" ]; then
    cleanup_dir "$TMP_DIR"
    test_pass "Title with --draft has [draft] prefix"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Expected '[draft][plan][feat]: Add test feature', got '$CAPTURED_TITLE'"
fi
