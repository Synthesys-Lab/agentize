#!/usr/bin/env bash
# Test: Plan issue baseline format

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-open-issue.sh"

test_info "Plan issue baseline format"

TMP_DIR=$(make_temp_dir "open-issue-plan-baseline")
GH_CAPTURE_FILE="$TMP_DIR/gh-capture.txt"
export GH_CAPTURE_FILE

# Setup gh mock
setup_gh_mock_open_issue "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Test plan issue baseline format
TITLE="[plan][feat]: Add test feature"
"$TMP_DIR/gh" issue create --title "$TITLE" --body "test"
CAPTURED_TITLE=$(grep "TITLE:" "$GH_CAPTURE_FILE" | cut -d' ' -f2-)

if [ "$CAPTURED_TITLE" = "[plan][feat]: Add test feature" ]; then
    cleanup_dir "$TMP_DIR"
    test_pass "Plan issue title has correct baseline format"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Expected '[plan][feat]: Add test feature', got '$CAPTURED_TITLE'"
fi
