#!/usr/bin/env bash
# Test: Verify draft prefix is preserved

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/helpers-refine-issue.sh"

test_info "Verify draft prefix is preserved"

TMP_DIR=$(make_temp_dir "refine-issue-draft")

# Setup gh mock
setup_gh_mock_refine "$TMP_DIR" "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Fetch issue
ISSUE_JSON=$("$TMP_DIR/gh" issue view 42 --json title,body,state)
ISSUE_TITLE=$(echo "$ISSUE_JSON" | grep -o '"title": "[^"]*"' | cut -d'"' -f4)

# The title should have [draft] prefix
if echo "$ISSUE_TITLE" | grep -q "\[draft\]"; then
    cleanup_dir "$TMP_DIR"
    test_pass "Draft prefix preserved in original issue"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Draft prefix missing"
fi
