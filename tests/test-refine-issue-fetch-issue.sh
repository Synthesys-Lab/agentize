#!/usr/bin/env bash
# Test: Fetch issue data

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/helpers-refine-issue.sh"

test_info "Fetch issue data"

TMP_DIR=$(make_temp_dir "refine-issue-fetch")

# Setup gh mock
setup_gh_mock_refine "$TMP_DIR" "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Test: Fetch issue data
ISSUE_JSON=$("$TMP_DIR/gh" issue view 42 --json title,body,state)
ISSUE_TITLE=$(echo "$ISSUE_JSON" | grep -o '"title": "[^"]*"' | cut -d'"' -f4)

if echo "$ISSUE_TITLE" | grep -q "\[draft\]\[plan\]\[feat\]"; then
    cleanup_dir "$TMP_DIR"
    test_pass "Issue fetched correctly"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Could not fetch issue title"
fi
