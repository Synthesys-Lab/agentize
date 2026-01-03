#!/usr/bin/env bash
# Test: Parse issue number and refinement instructions

source "$(dirname "$0")/../common.sh"

test_info "Parse issue number and refinement instructions"

# Mock arguments
MOCK_ARGUMENTS="42 Focus on reducing complexity"
PARSED_ISSUE_NUMBER=$(echo "$MOCK_ARGUMENTS" | awk '{print $1}')
PARSED_REFINEMENT=$(echo "$MOCK_ARGUMENTS" | cut -d' ' -f2-)

if [ "$PARSED_ISSUE_NUMBER" = "42" ] && [ "$PARSED_REFINEMENT" = "Focus on reducing complexity" ]; then
    test_pass "Arguments parsed correctly"
else
    test_fail "Argument parsing failed - Expected issue: 42, refinement: 'Focus on reducing complexity'"
fi
