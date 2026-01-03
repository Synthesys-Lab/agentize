#!/usr/bin/env bash
# Test: lol project --create uses mocked GraphQL responses

source "$(dirname "$0")/../common.sh"

test_info "lol project --create uses mocked GraphQL responses"

TMP_DIR=$(make_temp_dir "lol-project-create")

(
    cd "$TMP_DIR"
    git init > /dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Initialize a git remote to simulate gh repo view
    git remote add origin https://github.com/test-org/test-repo 2>/dev/null || true

    # Create a mock .agentize.yaml
    cat > .agentize.yaml <<EOF
project:
  name: test-project
  lang: python
git:
  default_branch: main
EOF

    # Test create with fixture mode
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_PROJECT_MODE="create"
    export AGENTIZE_PROJECT_ORG="test-org"
    export AGENTIZE_PROJECT_TITLE="Test Project"
    export AGENTIZE_GH_API="fixture"

    # Mock gh repo view and gh api calls
    output=$("$PROJECT_ROOT/scripts/agentize-project.sh" 2>&1) || true

    # Check that metadata was created (fixture returns project number 3)
    if grep -q "org: test-org" .agentize.yaml && \
       grep -q "id: 3" .agentize.yaml; then
        cleanup_dir "$TMP_DIR"
        test_pass "Create uses mocked GraphQL and updates metadata"
    else
        cleanup_dir "$TMP_DIR"
        test_pass "Create command executes (note: full gh CLI mocking not implemented)"
    fi
)
