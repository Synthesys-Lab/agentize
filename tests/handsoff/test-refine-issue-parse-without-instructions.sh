#!/usr/bin/env bash
# Test: Parse issue number without refinement instructions

source "$(dirname "$0")/../common.sh"

test_info "Parse issue number without refinement instructions"

# Mock arguments (issue number only)
MOCK_ARGUMENTS_SIMPLE="42"
PARSED_ISSUE_NUMBER_SIMPLE=$(echo "$MOCK_ARGUMENTS_SIMPLE" | awk '{print $1}')
PARSED_REFINEMENT_SIMPLE=$(echo "$MOCK_ARGUMENTS_SIMPLE" | cut -d' ' -f2-)

# When only issue number provided, refinement should equal issue number
# Command should detect this and clear refinement instructions
if [ "$PARSED_ISSUE_NUMBER_SIMPLE" = "42" ] && [ "$PARSED_REFINEMENT_SIMPLE" = "$PARSED_ISSUE_NUMBER_SIMPLE" ]; then
    test_pass "Issue-only arguments parsed correctly"
else
    test_fail "Issue-only argument parsing failed"
fi
