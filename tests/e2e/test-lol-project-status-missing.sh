#!/usr/bin/env bash
# Test: Status field verification auto-creates missing options

# Shared test helpers
set -e
SCRIPT_PATH="$0"
if [ -n "${BASH_SOURCE[0]-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
if [ "${SCRIPT_PATH%/*}" = "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="."
else
  SCRIPT_DIR="${SCRIPT_PATH%/*}"
fi
source "$SCRIPT_DIR/../common.sh"

test_info "Status field verification auto-creates missing options"

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
    output=$(project_verify_status_options "test-org" 3 2>&1)
    exit_code=$?

    # Check that missing options are detected and auto-creation is attempted
    if echo "$output" | grep -q "Missing required Status options" && \
       echo "$output" | grep -q "Refining" && \
       echo "$output" | grep -q "Plan Accepted"; then
        # Check that auto-creation is attempted
        if echo "$output" | grep -q "Creating missing options"; then
            # Check that creation succeeds (in fixture mode)
            if echo "$output" | grep -q "done" && \
               echo "$output" | grep -q "All missing Status options created successfully"; then
                cleanup_dir "$TMP_DIR"
                test_pass "Status verification auto-creates missing options"
            else
                cleanup_dir "$TMP_DIR"
                test_fail "Status verification should succeed in creating options (fixture mode)"
            fi
        else
            cleanup_dir "$TMP_DIR"
            test_fail "Status verification should attempt to create missing options"
        fi
    else
        cleanup_dir "$TMP_DIR"
        test_fail "Status verification should detect missing options (Refining, Plan Accepted)"
    fi
)
