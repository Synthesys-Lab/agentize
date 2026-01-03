#!/usr/bin/env bash
# Test: lol project --automation --write outputs PAT setup guidance

source "$(dirname "$0")/../common.sh"

test_info "lol project --automation --write outputs PAT setup guidance"

TMP_DIR=$(make_temp_dir "lol-project-automation-write")

(
    cd "$TMP_DIR"
    git init > /dev/null 2>&1

    # Add org and id to metadata for automation test
    cat > .agentize.yaml <<EOF
project:
  name: test-project
  lang: python
  org: test-org
  id: 42
git:
  default_branch: main
EOF

    # Test automation template generation with --write
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_PROJECT_MODE="automation"
    export AGENTIZE_PROJECT_WRITE_PATH=".github/workflows/add-to-project.yml"

    output=$("$PROJECT_ROOT/scripts/agentize-project.sh" 2>&1) || true

    # Test case 1: Output includes PAT creation with required project read/write permission
    if ! echo "$output" | grep -qi "project.*read.*write"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Missing PAT permission guidance (project read/write)"
    fi

    # Test case 2: Output includes gh secret set command
    if ! echo "$output" | grep -q "gh secret set ADD_TO_PROJECT_PAT"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Missing 'gh secret set ADD_TO_PROJECT_PAT' command"
    fi

    # Test case 3: Output includes reference to documentation
    if ! echo "$output" | grep -q "docs/workflows/github-projects-automation.md"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Missing documentation reference"
    fi

    cleanup_dir "$TMP_DIR"
    test_pass "PAT setup guidance includes all required elements"
)
