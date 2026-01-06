#!/usr/bin/env bash
# Test: lol project --associate preserves existing metadata fields

source "$(dirname "$0")/../common.sh"

test_info "lol project --associate preserves existing metadata fields"

TMP_DIR=$(make_temp_dir "lol-project-metadata-preservation")

(
    cd "$TMP_DIR"
    git init > /dev/null 2>&1

    # Create .agentize.yaml with existing fields
    cat > .agentize.yaml <<EOF
project:
  name: test-project
  lang: python
  source: src
git:
  default_branch: main
  remote_url: https://github.com/test/repo
EOF

    # Run associate in fixture mode
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_PROJECT_MODE="associate"
    export AGENTIZE_PROJECT_ASSOCIATE="Synthesys-Lab/3"
    export AGENTIZE_GH_API="fixture"

    "$PROJECT_ROOT/scripts/agentize-project.sh" > /dev/null 2>&1 || true

    # Check that existing fields are preserved
    if grep -q "name: test-project" .agentize.yaml && \
       grep -q "lang: python" .agentize.yaml && \
       grep -q "source: src" .agentize.yaml && \
       grep -q "remote_url: https://github.com/test/repo" .agentize.yaml; then
        # Check that new fields were added
        if grep -q "org: Synthesys-Lab" .agentize.yaml && \
           grep -q "id: 3" .agentize.yaml; then
            cleanup_dir "$TMP_DIR"
            test_pass "Metadata preserved and new fields added"
        else
            cleanup_dir "$TMP_DIR"
            test_fail "New fields not added"
        fi
    else
        cleanup_dir "$TMP_DIR"
        test_fail "Existing metadata not preserved"
    fi
)
