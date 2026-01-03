#!/usr/bin/env bash
# Test: lol init --metadata-only preserves existing .agentize.yaml

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "lol init --metadata-only preserves existing .agentize.yaml"

TEST_PROJECT=$(make_temp_dir "agentize-cli-metadata-only-preserves-yaml")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Create existing .agentize.yaml with custom values
cat > "$TEST_PROJECT/.agentize.yaml" <<EOF
project:
  name: existing-project
  lang: cxx
  source: custom/path
git:
  default_branch: develop
EOF

# Run init with --metadata-only
lol init --name new-project --lang python --path "$TEST_PROJECT" --metadata-only 2>/dev/null

# Verify existing values are preserved
if ! grep -q "name: existing-project" "$TEST_PROJECT/.agentize.yaml"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "metadata-only init overwrote existing project name"
fi

if ! grep -q "lang: cxx" "$TEST_PROJECT/.agentize.yaml"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "metadata-only init overwrote existing language"
fi

if ! grep -q "default_branch: develop" "$TEST_PROJECT/.agentize.yaml"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "metadata-only init overwrote existing default_branch"
fi

cleanup_dir "$TEST_PROJECT"
test_pass "metadata-only mode preserves existing .agentize.yaml"
