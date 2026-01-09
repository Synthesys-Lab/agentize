#!/usr/bin/env bash
# Test: lol update creates .agentize.yaml if missing

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol update creates .agentize.yaml if missing"

TEST_PROJECT=$(make_temp_dir "agentize-cli-update-creates-agentize-yaml")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Run update with explicit path (should create .agentize.yaml)
lol update --path "$TEST_PROJECT" 2>/dev/null

# Verify .agentize.yaml was created
if [ ! -f "$TEST_PROJECT/.agentize.yaml" ]; then
  cleanup_dir "$TEST_PROJECT"
  test_fail ".agentize.yaml was not created by lol update"
fi

# Verify agentize.commit field exists when AGENTIZE_HOME is a git repo
if ! grep -q "agentize:" "$TEST_PROJECT/.agentize.yaml"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail ".agentize.yaml does not contain agentize section"
fi

if ! grep -q "commit:" "$TEST_PROJECT/.agentize.yaml"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail ".agentize.yaml does not contain agentize.commit field"
fi

cleanup_dir "$TEST_PROJECT"
test_pass "lol update creates .agentize.yaml when missing"
