#!/usr/bin/env bash
# Test: lol --version displays version information

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "lol --version displays version information"

TEST_PROJECT=$(make_temp_dir "agentize-cli-version-test")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Create .agentize.yaml with commit hash
cat > "$TEST_PROJECT/.agentize.yaml" <<EOF
project:
  name: test-project
  lang: python
agentize:
  commit: a1b2c3d4567890abcdef1234567890abcdef123
EOF

# Run lol --version from test project directory
cd "$TEST_PROJECT" || test_fail "Failed to change directory to test project"
output=$(lol --version 2>&1)

# Verify output includes "Installation:" line
echo "$output" | grep -q "Installation:" || {
  cleanup_dir "$TEST_PROJECT"
  test_fail "Output missing 'Installation:' line"
}

# Verify output includes "Last update:" line
echo "$output" | grep -q "Last update:" || {
  cleanup_dir "$TEST_PROJECT"
  test_fail "Output missing 'Last update:' line"
}

# Verify output includes the commit hash from .agentize.yaml
echo "$output" | grep -q "a1b2c3d4567890abcdef1234567890abcdef123" || {
  cleanup_dir "$TEST_PROJECT"
  test_fail "Output missing commit hash from .agentize.yaml"
}

cleanup_dir "$TEST_PROJECT"
test_pass "lol --version displays correct version information"
