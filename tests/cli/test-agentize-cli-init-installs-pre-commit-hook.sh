#!/usr/bin/env bash
# Test: lol init installs pre-commit hook when scripts/pre-commit exists

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "lol init installs pre-commit hook"

# Unset git environment variables to avoid interference from parent git process
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_INDEX_VERSION GIT_COMMON_DIR

TEST_PROJECT=$(make_temp_dir "agentize-cli-init-installs-pre-commit-hook")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Initialize git repo first (lol init now allows directories with only .git)
cd "$TEST_PROJECT"
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Initialize project (should install hook)
lol init --name test-project --lang python --path "$TEST_PROJECT" 2>/dev/null

# Verify hook was installed
if [ ! -L "$TEST_PROJECT/.git/hooks/pre-commit" ]; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "pre-commit hook symlink not created"
fi

# Verify it points to scripts/pre-commit
HOOK_TARGET=$(readlink "$TEST_PROJECT/.git/hooks/pre-commit")
if [[ ! "$HOOK_TARGET" =~ scripts/pre-commit ]]; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "pre-commit hook doesn't point to scripts/pre-commit (got: $HOOK_TARGET)"
fi

cleanup_dir "$TEST_PROJECT"
test_pass "lol init installs pre-commit hook"
