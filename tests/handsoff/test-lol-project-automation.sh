#!/usr/bin/env bash
# Test: lol project --automation outputs workflow template

source "$(dirname "$0")/../common.sh"

test_info "lol project --automation outputs workflow template"

TMP_DIR=$(make_temp_dir "lol-project-automation")

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

    # Test automation template generation
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_PROJECT_MODE="automation"
    output=$("$PROJECT_ROOT/scripts/agentize-project.sh" 2>&1) || true

    # Check output contains workflow YAML
    if ! echo "$output" | grep -q "name: Add issues and PRs to project"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing workflow name"
    fi

    # Check that org and id are substituted
    if ! echo "$output" | grep -q "PROJECT_ORG: test-org"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing org substitution"
    fi

    if ! echo "$output" | grep -q "PROJECT_ID: 42"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing id substitution"
    fi

    # Check for Stage field configuration (new env vars)
    if ! echo "$output" | grep -q "STAGE_FIELD_ID:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing STAGE_FIELD_ID env var"
    fi

    if ! echo "$output" | grep -q "STAGE_DONE_OPTION_ID:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing STAGE_DONE_OPTION_ID env var"
    fi

    # Check for status-field/status-value in issue add step
    if ! echo "$output" | grep -q "status-field:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing status-field for issues"
    fi

    if ! echo "$output" | grep -q "status-value:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing status-value for issues"
    fi

    # Check for pull_request closed trigger
    if ! echo "$output" | grep -q "pull_request:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing pull_request trigger"
    fi

    if ! echo "$output" | grep -q "closed"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing closed event type"
    fi

    # Check for GraphQL PR-merge automation
    if ! echo "$output" | grep -q "closingIssuesReferences"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing closingIssuesReferences query"
    fi

    if ! echo "$output" | grep -q "updateProjectV2ItemFieldValue"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing updateProjectV2ItemFieldValue mutation"
    fi

    cleanup_dir "$TMP_DIR"
    test_pass "Automation template generated with enhanced lifecycle automation"
)
