#!/usr/bin/env bash
# Test: lol update installs pre-commit hook

source "$(dirname "$0")/common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "lol update installs pre-commit hook"

# Unset git environment variables to avoid interference from parent git process
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_INDEX_VERSION GIT_COMMON_DIR

TEST_PROJECT=$(make_temp_dir "agentize-cli-update-installs-pre-commit-hook")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Initialize git repo and create .claude/
cd "$TEST_PROJECT"
git init
git config user.email "test@example.com"
git config user.name "Test User"
mkdir -p .claude

# Run update (should install hook)
lol update 2>/dev/null

# Verify hook was installed
if [ ! -L "$TEST_PROJECT/.git/hooks/pre-commit" ]; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "pre-commit hook symlink not created by lol update"
fi

cleanup_dir "$TEST_PROJECT"
test_pass "lol update installs pre-commit hook"
