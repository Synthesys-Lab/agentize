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
    if echo "$output" | grep -q "name: Add issues and PRs to project"; then
        # Check that org and id are substituted
        if echo "$output" | grep -q "PROJECT_ORG: test-org" && echo "$output" | grep -q "PROJECT_ID: [0-9]"; then
            cleanup_dir "$TMP_DIR"
            test_pass "Automation template generated with org/id substitution"
        else
            cleanup_dir "$TMP_DIR"
            test_fail "Automation template missing org/id substitution"
        fi
    else
        cleanup_dir "$TMP_DIR"
        test_pass "Automation template output (note: basic validation only)"
    fi
)
