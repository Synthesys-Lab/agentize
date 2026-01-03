#!/usr/bin/env bash
# Test: Verify refined plan content

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/helpers-refine-issue.sh"

test_info "Verify refined plan content"

TMP_DIR=$(make_temp_dir "refine-issue-verify")

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

# Update issue to trigger body capture
"$TMP_DIR/gh" issue edit 42 --body-file "$REFINED_PLAN_FILE"

if [ -f "$TMP_DIR/gh-edit-body-capture.txt" ] && grep -q "rate limiting" "$TMP_DIR/gh-edit-body-capture.txt"; then
    cleanup_dir "$TMP_DIR"
    test_pass "Refined plan contains improvements"
else
    cleanup_dir "$TMP_DIR"
    test_fail "Refined plan content incorrect"
fi
