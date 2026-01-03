#!/usr/bin/env bash
# Test: Update issue with refined plan

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/helpers-refine-issue.sh"

test_info "Update issue with refined plan"

TMP_DIR=$(make_temp_dir "refine-issue-update")

# Setup gh mock
setup_gh_mock_refine "$TMP_DIR" "$TMP_DIR"
export PATH="$TMP_DIR:$PATH"

# Create refined plan
REFINED_PLAN_FILE="$TMP_DIR/consensus-plan-refined.md"
cat > "$REFINED_PLAN_FILE" <<'EOF'
## Description

Add user authentication with JWT tokens and improved security.

## Proposed Solution

### Implementation Steps
1. Add auth middleware with rate limiting
2. Create JWT utilities with refresh tokens
3. Add login endpoint with 2FA support
4. Add security tests

Total LOC: ~200 (Medium)
EOF

# Update issue
"$TMP_DIR/gh" issue edit 42 --body-file "$REFINED_PLAN_FILE"

if [ -f "$TMP_DIR/gh-edit-capture.txt" ] && grep -q "Issue 42 updated" "$TMP_DIR/gh-edit-capture.txt"; then
    cleanup_dir "$TMP_DIR"
    test_pass "Issue update command executed"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Issue update failed"
fi
