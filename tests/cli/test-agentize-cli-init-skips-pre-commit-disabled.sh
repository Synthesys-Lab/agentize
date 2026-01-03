#!/usr/bin/env bash
# Test: lol init skips hook when pre_commit.enabled is false

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "lol init skips hook when pre_commit.enabled is false"

# Unset git environment variables to avoid interference from parent git process
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_INDEX_VERSION GIT_COMMON_DIR

TEST_PROJECT=$(make_temp_dir "agentize-cli-init-skips-pre-commit-disabled")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Initialize git repo
cd "$TEST_PROJECT"
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Create .agentize.yaml with pre_commit.enabled: false BEFORE lol init
cat > "$TEST_PROJECT/.agentize.yaml" <<EOF
project:
  name: test-project
  lang: python
pre_commit:
  enabled: false
EOF

# Initialize project (should NOT install hook due to metadata)
lol init --name test-project --lang python --path "$TEST_PROJECT" 2>/dev/null

# Verify hook was NOT installed
if [ -f "$TEST_PROJECT/.git/hooks/pre-commit" ] || [ -L "$TEST_PROJECT/.git/hooks/pre-commit" ]; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "pre-commit hook should not be installed when disabled in metadata"
fi

cleanup_dir "$TEST_PROJECT"
test_pass "lol init respects pre_commit.enabled: false"
