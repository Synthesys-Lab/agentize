#!/usr/bin/env bash
# Test: lol apply --init/--update delegates correctly to init/update modes

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol apply delegates correctly to init/update modes"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Test 1: lol apply --init enforces --name and --lang
exit_code=0
output=$(lol apply --init 2>&1) || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  test_fail "lol apply --init without --name should fail"
fi

echo "$output" | grep -q -i "name" || test_fail "Error message should mention --name"

exit_code=0
output=$(lol apply --init --name test-project 2>&1) || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  test_fail "lol apply --init without --lang should fail"
fi

echo "$output" | grep -q -i "lang" || test_fail "Error message should mention --lang"

# Test 2: lol apply --update creates .claude/ in target directory
TMP_DIR=$(mktemp -d)
trap "rm -rf '$TMP_DIR'" EXIT

# Create a git repo for the test
mkdir -p "$TMP_DIR/test-project"
git -C "$TMP_DIR/test-project" init --quiet

# Run lol apply --update
exit_code=0
output=$(lol apply --update --path "$TMP_DIR/test-project" 2>&1) || exit_code=$?
if [ "$exit_code" -ne 0 ]; then
  test_fail "lol apply --update should succeed: $output"
fi

# Verify .claude/ was created
if [ ! -d "$TMP_DIR/test-project/.claude" ]; then
  test_fail "lol apply --update should create .claude/ directory"
fi

test_pass "lol apply delegates correctly to init/update modes"
