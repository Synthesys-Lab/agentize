#!/usr/bin/env bash
# Test: apply --update creates .claude/ when not found

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "apply --update creates .claude/ when not found"

TEST_PROJECT=$(make_temp_dir "agentize-cli-update-creates-claude-dir")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Should succeed and create .claude/
if ! lol apply --update --path "$TEST_PROJECT" 2>/dev/null; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "Should succeed and create .claude/"
fi

# Verify .claude/ was created
if [ ! -d "$TEST_PROJECT/.claude" ]; then
  cleanup_dir "$TEST_PROJECT"
  test_fail ".claude/ directory was not created"
fi

cleanup_dir "$TEST_PROJECT"
test_pass "Correctly creates .claude/ when not found"
