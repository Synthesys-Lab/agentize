#!/usr/bin/env bash
# Purpose: Shared helper providing worktree test setup functions
# Expected: Sourced by worktree tests to create test environments

# Source gh mock helpers (use TESTS_DIR from common.sh for shell-neutral sourcing)
source "$TESTS_DIR/helpers-gh-mock.sh"

# Create a bare test repository with basic setup
# Returns the test directory path in TEST_REPO_DIR
setup_test_repo() {
    clean_git_env

    # Create temp directory for seed repo
    local SEED_DIR=$(mktemp -d)
    cd "$SEED_DIR"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial commit
    echo "test" > README.md
    git add README.md
    git commit -m "Initial commit"

    # Clone as bare repo
    TEST_REPO_DIR=$(mktemp -d)
    git clone --bare "$SEED_DIR" "$TEST_REPO_DIR"
    cd "$TEST_REPO_DIR"

    # Clean up seed repo
    rm -rf "$SEED_DIR"

    # Copy src/cli/wt.sh as wt-cli.sh for test sourcing
    cp "$PROJECT_ROOT/src/cli/wt.sh" ./wt-cli.sh

    # Copy wt/ module directory for modular loading
    cp -r "$PROJECT_ROOT/src/cli/wt" ./wt

    # Create gh stub for testing
    create_gh_stub
}

# Setup bare test repo with custom default branch via WT_DEFAULT_BRANCH env
# Usage: setup_test_repo_custom_branch "trunk"
setup_test_repo_custom_branch() {
    local branch_name="$1"

    clean_git_env

    # Create temp directory for seed repo
    local SEED_DIR=$(mktemp -d)
    cd "$SEED_DIR"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial commit on custom branch
    git checkout -b "$branch_name"
    echo "test" > README.md
    git add README.md
    git commit -m "Initial commit"

    # Clone as bare repo
    TEST_REPO_DIR=$(mktemp -d)
    git clone --bare "$SEED_DIR" "$TEST_REPO_DIR"
    cd "$TEST_REPO_DIR"

    # Clean up seed repo
    rm -rf "$SEED_DIR"

    # Set WT_DEFAULT_BRANCH for wt to use
    export WT_DEFAULT_BRANCH="$branch_name"

    # Copy src/cli/wt.sh as wt-cli.sh for test sourcing
    cp "$PROJECT_ROOT/src/cli/wt.sh" ./wt-cli.sh

    # Copy wt/ module directory for modular loading
    cp -r "$PROJECT_ROOT/src/cli/wt" ./wt

    # Create gh stub for testing
    create_gh_stub
}

# Setup test repo with pre-commit hook
setup_test_repo_with_precommit() {
    setup_test_repo

    # Create scripts/pre-commit
    mkdir -p scripts
    cat > scripts/pre-commit <<'EOF'
#!/usr/bin/env bash
echo "Pre-commit hook running"
exit 0
EOF
    chmod +x scripts/pre-commit
}

# Cleanup test repository
cleanup_test_repo() {
    if [ -n "$TEST_REPO_DIR" ] && [ -d "$TEST_REPO_DIR" ]; then
        cd /
        rm -rf "$TEST_REPO_DIR"
        unset TEST_REPO_DIR
    fi
}
