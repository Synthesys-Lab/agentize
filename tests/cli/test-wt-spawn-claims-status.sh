#!/usr/bin/env bash
# Test: wt spawn claims issue status as "In Progress" via GitHub Projects API

source "$(dirname "$0")/../common.sh"
source "$(dirname "$0")/../helpers-worktree.sh"

test_info "wt spawn claims issue status as In Progress"

# Custom setup that includes .agentize.yaml and git remote in seed repo
setup_test_repo_with_project_config() {
    clean_git_env

    # Create temp directory for seed repo
    local SEED_DIR=$(mktemp -d)
    cd "$SEED_DIR"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial commit with .agentize.yaml
    echo "test" > README.md
    cat > .agentize.yaml <<'EOF'
project:
  org: test-org
  id: 3
EOF
    git add README.md .agentize.yaml
    git commit -m "Initial commit with project config"

    # Add a fake origin remote (needed for repo parsing)
    git remote add origin https://github.com/test-org/test-repo.git

    # Clone as bare repo
    TEST_REPO_DIR=$(mktemp -d)
    git clone --bare "$SEED_DIR" "$TEST_REPO_DIR"
    cd "$TEST_REPO_DIR"

    # Set origin remote to GitHub URL (clone --bare sets it to the local seed dir)
    git remote set-url origin https://github.com/test-org/test-repo.git

    # Clean up seed repo
    rm -rf "$SEED_DIR"

    # Copy src/cli/wt.sh as wt-cli.sh for test sourcing
    cp "$PROJECT_ROOT/src/cli/wt.sh" ./wt-cli.sh

    # Copy wt/ module directory for modular loading
    cp -r "$PROJECT_ROOT/src/cli/wt" ./wt

    # Copy scripts/gh-graphql.sh for fixture mode
    mkdir -p scripts
    cp "$PROJECT_ROOT/scripts/gh-graphql.sh" ./scripts/gh-graphql.sh
    chmod +x ./scripts/gh-graphql.sh

    # Copy test fixtures
    mkdir -p tests/fixtures/github-projects
    cp "$PROJECT_ROOT/tests/fixtures/github-projects/"*.json ./tests/fixtures/github-projects/

    # Create gh stub for testing
    create_gh_stub
}

setup_test_repo_with_project_config
source ./wt-cli.sh

# Initialize wt environment
wt init >/dev/null 2>&1 || test_fail "wt init failed"

# Enable fixture mode for gh-graphql.sh
export AGENTIZE_GH_API=fixture

# Spawn worktree for issue 42 (no agent to avoid Claude invocation)
cd "$TEST_REPO_DIR"
spawn_output=$(wt spawn 42 --no-agent 2>&1)
spawn_exit=$?

if [ $spawn_exit -ne 0 ]; then
  cleanup_test_repo
  test_fail "wt spawn 42 failed with exit code $spawn_exit: $spawn_output"
fi

# Verify worktree was created
issue_dir=$(find "$TEST_REPO_DIR/trees" -maxdepth 1 -type d -name "issue-42*" 2>/dev/null | head -1)
if [ -z "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "issue-42 worktree was not created"
fi

# Verify status claim message appears in output
if ! echo "$spawn_output" | grep -qi "in progress"; then
  echo "DEBUG: spawn_output = $spawn_output" >&2
  cleanup_test_repo
  test_fail "spawn output should mention status update to In Progress"
fi

# Test: spawn still succeeds when project config is missing
# First, create a repo without .agentize.yaml
setup_test_repo
source ./wt-cli.sh
wt init >/dev/null 2>&1 || test_fail "wt init failed for second repo"

cd "$TEST_REPO_DIR"
spawn_output=$(wt spawn 55 --no-agent 2>&1)
spawn_exit=$?

if [ $spawn_exit -ne 0 ]; then
  cleanup_test_repo
  test_fail "wt spawn should succeed even without project config"
fi

# Verify worktree was created
issue_dir=$(find "$TEST_REPO_DIR/trees" -maxdepth 1 -type d -name "issue-55*" 2>/dev/null | head -1)
if [ -z "$issue_dir" ]; then
  cleanup_test_repo
  test_fail "issue-55 worktree was not created"
fi

cleanup_test_repo
test_pass "wt spawn correctly claims issue status"
