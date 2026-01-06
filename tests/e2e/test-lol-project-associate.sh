#!/usr/bin/env bash
# Test: lol project --associate updates .agentize.yaml

source "$(dirname "$0")/../common.sh"

test_info "lol project --associate updates .agentize.yaml"

TMP_DIR=$(make_temp_dir "lol-project-associate")

(
    cd "$TMP_DIR"
    git init > /dev/null 2>&1

    # Create a mock .agentize.yaml
    cat > .agentize.yaml <<EOF
project:
  name: test-project
  lang: python
git:
  default_branch: main
EOF

    # Test associate with fixture mode
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_PROJECT_MODE="associate"
    export AGENTIZE_PROJECT_ASSOCIATE="test-org/42"
    export AGENTIZE_GH_API="fixture"

    "$PROJECT_ROOT/scripts/agentize-project.sh" > /dev/null 2>&1 || true

    # Check that metadata was updated
    if grep -q "org: test-org" .agentize.yaml && \
       grep -q "id: 42" .agentize.yaml; then
        cleanup_dir "$TMP_DIR"
        test_pass "Associate updates .agentize.yaml with org and id"
    else
        cleanup_dir "$TMP_DIR"
        test_fail "Metadata not updated"
    fi
)
