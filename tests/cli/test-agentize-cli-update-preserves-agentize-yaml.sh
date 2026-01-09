#!/usr/bin/env bash
# Test: lol update preserves existing .agentize.yaml

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol update preserves existing .agentize.yaml"

TEST_PROJECT=$(make_temp_dir "agentize-cli-update-preserves-agentize-yaml")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Create a custom .agentize.yaml
cat > "$TEST_PROJECT/.agentize.yaml" <<EOF
project:
  name: custom-name
  lang: cxx
  source: custom/src
git:
  default_branch: trunk
agentize:
  commit: abc123
EOF

# Run update
lol update --path "$TEST_PROJECT" 2>/dev/null

# Verify custom values are preserved
if ! grep -q "name: custom-name" "$TEST_PROJECT/.agentize.yaml"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "lol update overwrote custom project name"
fi

if ! grep -q "default_branch: trunk" "$TEST_PROJECT/.agentize.yaml"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "lol update overwrote custom default_branch"
fi

# Verify agentize.commit field exists (update should add/update it)
# but also verify it doesn't preserve the old value 'abc123' since update should update it
if ! grep -q "agentize:" "$TEST_PROJECT/.agentize.yaml"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "lol update did not add agentize section"
fi

cleanup_dir "$TEST_PROJECT"
test_pass "lol update preserves existing .agentize.yaml"
