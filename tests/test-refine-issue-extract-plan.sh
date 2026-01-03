#!/usr/bin/env bash
# Test: Extract plan from issue body

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/helpers-refine-issue.sh"

test_info "Extract plan from issue body"

TMP_DIR=$(make_temp_dir "refine-issue-extract")

# Setup gh mock
setup_gh_mock_refine "$TMP_DIR" "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Fetch issue and extract plan
ISSUE_JSON=$("$TMP_DIR/gh" issue view 42 --json title,body,state)
ISSUE_BODY=$(echo "$ISSUE_JSON" | sed -n 's/.*"body": "\(.*\)",/\1/p' | sed 's/\\n/\n/g')
TEMP_PLAN_FILE="$TMP_DIR/issue-42-original.md"
echo "$ISSUE_BODY" > "$TEMP_PLAN_FILE"

if [ -f "$TEMP_PLAN_FILE" ] && grep -q "Implementation Steps" "$TEMP_PLAN_FILE"; then
    cleanup_dir "$TMP_DIR"
    test_pass "Plan extracted to temp file"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Plan extraction failed"
fi
