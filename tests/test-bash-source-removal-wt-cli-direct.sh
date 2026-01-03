#!/usr/bin/env bash
# Test: wt-cli.sh executed directly should show sourced-only note

source "$(dirname "$0")/common.sh"

test_info "wt-cli.sh executed directly should show sourced-only note"

OUTPUT=$("$PROJECT_ROOT/scripts/wt-cli.sh" main 2>&1 || true)
if echo "$OUTPUT" | grep -q "sourced"; then
    test_pass "Sourced-only message displayed correctly"
else
    test_fail "Expected sourced-only message not found"
fi
