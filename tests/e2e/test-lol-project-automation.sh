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

    # Check for Stage field configuration (only STAGE_FIELD_ID needed)
    if ! echo "$output" | grep -q "STAGE_FIELD_ID:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing STAGE_FIELD_ID env var"
    fi

    # Verify STAGE_DONE_OPTION_ID is NOT present (simplified workflow)
    if echo "$output" | grep -q "STAGE_DONE_OPTION_ID:"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template should not have STAGE_DONE_OPTION_ID (simplified to issue closing)"
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

    # Check for simplified PR-merge automation (issue closing instead of field updates)
    if ! echo "$output" | grep -q "closingIssuesReferences"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing closingIssuesReferences query"
    fi

    # Verify workflow uses gh issue close instead of GraphQL mutations
    if ! echo "$output" | grep -q "gh issue close"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template should use 'gh issue close' for lifecycle management"
    fi

    # Verify updateProjectV2ItemFieldValue is NOT present (simplified workflow)
    if echo "$output" | grep -q "updateProjectV2ItemFieldValue"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template should not use updateProjectV2ItemFieldValue (simplified to issue closing)"
    fi

    # Check for archive-pr-on-merge job
    if ! echo "$output" | grep -q "archive-pr-on-merge"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing archive-pr-on-merge job"
    fi

    # Check for archiveProjectV2Item mutation
    if ! echo "$output" | grep -q "archiveProjectV2Item"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing archiveProjectV2Item mutation"
    fi

    # Check for merged guard in archive job
    if ! echo "$output" | grep -q "github.event.pull_request.merged == true"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation template missing merged guard for archive job"
    fi

    cleanup_dir "$TMP_DIR"
    test_pass "Automation template generated with enhanced lifecycle automation"
)
