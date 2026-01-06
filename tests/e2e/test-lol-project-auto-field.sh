#!/usr/bin/env bash
# Test: lol project --automation auto-creates Stage field

source "$(dirname "$0")/../common.sh"

test_info "lol project --automation auto-creates Stage field"

TMP_DIR=$(make_temp_dir "lol-project-auto-field")

(
    cd "$TMP_DIR"
    git init > /dev/null 2>&1

    # Add org and id to metadata
    cat > .agentize.yaml <<EOF
project:
  name: test-project
  lang: python
  org: test-org
  id: 42
git:
  default_branch: main
EOF

    # Test with fixture mode (simulates API calls)
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_PROJECT_MODE="automation"
    export AGENTIZE_PROJECT_WRITE_PATH=".github/workflows/project.yml"
    export AGENTIZE_GH_API="fixture"

    # Run automation command
    output=$("$PROJECT_ROOT/scripts/agentize-project.sh" 2>&1) || true

    # Check that Stage field was found/created
    if ! echo "$output" | grep -q "Configuring Stage field"; then
        cleanup_dir "$TMP_DIR"
        test_fail "Automation should attempt to configure Stage field"
    fi

    # Check that workflow file was created
    if [ ! -f ".github/workflows/project.yml" ]; then
        cleanup_dir "$TMP_DIR"
        test_fail "Workflow file not created"
    fi

    # Read the generated workflow file
    workflow_content=$(cat ".github/workflows/project.yml")

    # Verify STAGE_FIELD_ID is NOT a placeholder (should be auto-filled)
    # In fixture mode, it should find existing Status field or create new Stage field
    if echo "$workflow_content" | grep -q "STAGE_FIELD_ID: YOUR_STAGE_FIELD_ID_HERE"; then
        cleanup_dir "$TMP_DIR"
        test_fail "STAGE_FIELD_ID should be auto-filled, not placeholder"
    fi

    # Verify STAGE_FIELD_ID has a real value
    if ! echo "$workflow_content" | grep -q "STAGE_FIELD_ID: PVTSSF_"; then
        cleanup_dir "$TMP_DIR"
        test_fail "STAGE_FIELD_ID should have real GraphQL ID (PVTSSF_*)"
    fi

    # Verify org and id are filled
    if ! echo "$workflow_content" | grep -q "PROJECT_ORG: test-org"; then
        cleanup_dir "$TMP_DIR"
        test_fail "PROJECT_ORG not substituted"
    fi

    if ! echo "$workflow_content" | grep -q "PROJECT_ID: 42"; then
        cleanup_dir "$TMP_DIR"
        test_fail "PROJECT_ID not substituted"
    fi

    cleanup_dir "$TMP_DIR"
    test_pass "Stage field auto-configured successfully"
)
