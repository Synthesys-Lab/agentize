#!/usr/bin/env bash
# Test: lol init creates .agentize.yaml

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol init creates .agentize.yaml"

TEST_PROJECT=$(make_temp_dir "agentize-cli-init-creates-agentize-yaml")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Initialize a project
lol init --name test-project --lang python --path "$TEST_PROJECT" 2>/dev/null

# Verify .agentize.yaml was created
if [ ! -f "$TEST_PROJECT/.agentize.yaml" ]; then
  cleanup_dir "$TEST_PROJECT"
  test_fail ".agentize.yaml was not created by lol init"
fi

# Verify it contains expected project metadata
if ! grep -q "name: test-project" "$TEST_PROJECT/.agentize.yaml"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail ".agentize.yaml missing project name"
fi

if ! grep -q "lang: python" "$TEST_PROJECT/.agentize.yaml"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail ".agentize.yaml missing project language"
fi

cleanup_dir "$TEST_PROJECT"
test_pass "lol init creates .agentize.yaml with metadata"
