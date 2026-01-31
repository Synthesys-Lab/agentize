#!/usr/bin/env bash
# Test: lol project without .agentize.yaml shows helpful error

# Shared test helpers
set -e
TESTS_COMMON="${AGENTIZE_TESTS_COMMON:-$(git rev-parse --show-toplevel 2>/dev/null)/tests/common.sh}"
[ -f "$TESTS_COMMON" ] || { echo "Error: Cannot locate tests/common.sh" >&2; exit 1; }
source "$TESTS_COMMON"

test_info "lol project without .agentize.yaml shows helpful error"

TMP_DIR=$(make_temp_dir "lol-project-missing-metadata")

(
    cd "$TMP_DIR"
    git init > /dev/null 2>&1

    # Test that associate shows helpful error without .agentize.yaml
    export AGENTIZE_HOME="$PROJECT_ROOT"
    export AGENTIZE_PROJECT_MODE="associate"
    export AGENTIZE_PROJECT_ASSOCIATE="test-org/42"
    export AGENTIZE_GH_API="fixture"

    output=$("$PROJECT_ROOT/scripts/agentize-project.sh" 2>&1) || true

    if echo "$output" | grep -q ".agentize.yaml not found"; then
        cleanup_dir "$TMP_DIR"
        test_pass "Shows helpful error when .agentize.yaml is missing"
    else
        cleanup_dir "$TMP_DIR"
        test_fail "Missing .agentize.yaml error"
    fi
)
