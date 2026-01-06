#!/usr/bin/env bash
# Shared helper functions for worktree tests

# Create a bare test repository with basic setup
# Returns the test directory path in TEST_REPO_DIR
setup_test_repo() {
    # Unset all git environment variables to ensure clean test environment
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
    unset GIT_INDEX_VERSION GIT_COMMON_DIR

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

    # Create gh stub that validates issue existence and returns status
    mkdir -p bin
    cat > bin/gh <<'GHSTUB'
#!/usr/bin/env bash
# Stub gh command for testing
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  issue_no="$3"
  # Handle --json state flag for purge testing
  if [ "$4" = "--json" ] && [ "$5" = "state" ]; then
    # Check if --jq flag is present
    if [ "$6" = "--jq" ] && [ "$7" = ".state" ]; then
      # Return just the state value (simulating jq extraction)
      case "$issue_no" in
        42|55|100|200|210|300) echo "OPEN"; exit 0 ;;
        56|211|301|350) echo "CLOSED"; exit 0 ;;
        *) exit 1 ;;
      esac
    else
      # Return full JSON (for other use cases)
      case "$issue_no" in
        42|55|100|200|210|300) echo '{"state":"OPEN"}'; exit 0 ;;
        56|211|301|350) echo '{"state":"CLOSED"}'; exit 0 ;;
        *) exit 1 ;;
      esac
    fi
  else
    # Valid issue numbers return exit code 0, invalid ones return 1
    case "$issue_no" in
      42|55|56|100|200|210|211|300|301|350) exit 0 ;;
      *) exit 1 ;;
    esac
  fi
fi
GHSTUB
    chmod +x bin/gh
    export PATH="$PWD/bin:$PATH"
}

# Setup bare test repo with custom default branch via WT_DEFAULT_BRANCH env
# Usage: setup_test_repo_custom_branch "trunk"
setup_test_repo_custom_branch() {
    local branch_name="$1"

    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
    unset GIT_INDEX_VERSION GIT_COMMON_DIR

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

    # Create gh stub
    mkdir -p bin
    cat > bin/gh <<'GHSTUB'
#!/usr/bin/env bash
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  issue_no="$3"
  if [ "$4" = "--json" ] && [ "$5" = "state" ]; then
    # Check if --jq flag is present
    if [ "$6" = "--jq" ] && [ "$7" = ".state" ]; then
      # Return just the state value (simulating jq extraction)
      case "$issue_no" in
        42|55|100|200|210|300) echo "OPEN"; exit 0 ;;
        56|211|301|350) echo "CLOSED"; exit 0 ;;
        *) exit 1 ;;
      esac
    else
      # Return full JSON (for other use cases)
      case "$issue_no" in
        42|55|100|200|210|300) echo '{"state":"OPEN"}'; exit 0 ;;
        56|211|301|350) echo '{"state":"CLOSED"}'; exit 0 ;;
        *) exit 1 ;;
      esac
    fi
  else
    case "$issue_no" in
      42|55|56|100|200|210|211|300|301|350) exit 0 ;;
      *) exit 1 ;;
    esac
  fi
fi
GHSTUB
    chmod +x bin/gh
    export PATH="$PWD/bin:$PATH"
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
