#!/usr/bin/env bash
# Test: scripts/gh-graphql.sh review-threads returns fixture JSON in fixture mode

source "$(dirname "$0")/../common.sh"

test_info "gh-graphql.sh review-threads returns expected fixture data"

# Run in fixture mode
export AGENTIZE_GH_API="fixture"

# Test 1: review-threads operation returns valid JSON
OUTPUT=$("$PROJECT_ROOT/scripts/gh-graphql.sh" review-threads TestOwner TestRepo 123)

if [ -z "$OUTPUT" ]; then
  test_fail "review-threads returned empty output"
fi

# Test 2: Verify JSON structure has required fields
if ! echo "$OUTPUT" | jq -e '.data.repository.pullRequest.reviewThreads.nodes' > /dev/null 2>&1; then
  test_fail "Missing reviewThreads.nodes structure in response"
fi

# Test 3: Verify unresolved threads are present with required fields
UNRESOLVED_COUNT=$(echo "$OUTPUT" | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .isOutdated == false)] | length')
if [ "$UNRESOLVED_COUNT" -lt 1 ]; then
  test_fail "Expected at least 1 unresolved non-outdated thread, got $UNRESOLVED_COUNT"
fi

# Test 4: Verify required fields exist on threads (path, line, isResolved)
FIRST_THREAD=$(echo "$OUTPUT" | jq '.data.repository.pullRequest.reviewThreads.nodes[0]')
if ! echo "$FIRST_THREAD" | jq -e '.path' > /dev/null 2>&1; then
  test_fail "Missing 'path' field on review thread"
fi
if ! echo "$FIRST_THREAD" | jq -e '.line' > /dev/null 2>&1; then
  test_fail "Missing 'line' field on review thread"
fi
if ! echo "$FIRST_THREAD" | jq -e 'has("isResolved")' > /dev/null 2>&1; then
  test_fail "Missing 'isResolved' field on review thread"
fi

# Test 5: Verify comments structure exists
if ! echo "$FIRST_THREAD" | jq -e '.comments.nodes' > /dev/null 2>&1; then
  test_fail "Missing 'comments.nodes' structure on review thread"
fi

test_pass "gh-graphql.sh review-threads returns expected fixture data"
