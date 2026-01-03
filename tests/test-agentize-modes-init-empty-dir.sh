#!/usr/bin/env bash
# Test: init mode with empty existing directory

source "$(dirname "$0")/common.sh"

test_info "init mode with empty existing directory"

TMP_DIR=$(make_temp_dir "mode-test-init-empty-dir")

# Creating SDK in empty existing directory
(
    export AGENTIZE_PROJECT_NAME="test_mode_2"
    export AGENTIZE_PROJECT_PATH="$TMP_DIR"
    export AGENTIZE_PROJECT_LANG="python"
    "$PROJECT_ROOT/scripts/agentize-init.sh"
)

if [ ! -d "$TMP_DIR/.claude" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "SDK structure not created"
fi

cleanup_dir "$TMP_DIR"
test_pass "init mode works with empty existing directory"
