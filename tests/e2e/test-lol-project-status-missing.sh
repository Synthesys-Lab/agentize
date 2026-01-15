#!/usr/bin/env bash
# Test: Status field verification reports missing options with guidance URL

source "$(dirname "$0")/../common.sh"

test_info "Status field verification reports missing options with guidance URL"

TMP_DIR=$(make_temp_dir "lol-project-status-missing")

(
    cd "$TMP_DIR"
    git init > /dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git remote add origin https://github.com/test-org/test-repo 2>/dev/null || true

    # Create a mock .agentize.yaml with project association
    cat > .agentize.yaml <<EOF
project:
  name: test-project
  lang: python
  org: test-org
  id: 3
git:
  default_branch: main
EOF

    # Source the shared library
    source "$PROJECT_ROOT/src/cli/lol/project-lib.sh"

    # Test verify status options with missing fixture
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_GH_API="fixture"
    export AGENTIZE_GH_FIXTURE_LIST_FIELDS="missing"

    # Call project_verify_status_options
    output=$(project_verify_status_options "test-org" 3 2>&1) || true

    # Check that missing options are reported
    if echo "$output" | grep -q "Missing required Status options" && \
       echo "$output" | grep -q "Refining" && \
       echo "$output" | grep -q "Plan Accepted"; then
        # Check that guidance URL is provided
        if echo "$output" | grep -q "https://github.com"; then
            cleanup_dir "$TMP_DIR"
            test_pass "Status verification reports missing options with guidance URL"
        else
            cleanup_dir "$TMP_DIR"
            test_fail "Status verification should include guidance URL"
        fi
    else
        cleanup_dir "$TMP_DIR"
        test_fail "Status verification should report missing options (Refining, Plan Accepted)"
    fi
)
