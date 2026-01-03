#!/usr/bin/env bash
# Test: Custom C++ SDK source path (lib/)

source "$(dirname "$0")/../common.sh"

test_info "Custom C++ SDK source path (lib/)"

TMP_DIR=$(make_temp_dir "cxx-sdk-test-lib")

# Creating C++ SDK with custom source path (lib/)
(
    export AGENTIZE_PROJECT_NAME="test-cxx-sdk-lib"
    export AGENTIZE_PROJECT_PATH="$TMP_DIR"
    export AGENTIZE_PROJECT_LANG="cxx"
    export AGENTIZE_SOURCE_PATH="lib"
    "$PROJECT_ROOT/scripts/agentize-init.sh"
)

# Verify lib/ directory exists and src/ does not
if [ -d "$TMP_DIR/src" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "src/ directory should not exist when using custom SOURCE_PATH"
fi

if [ ! -d "$TMP_DIR/lib" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "lib/ directory not found"
fi

if [ ! -f "$TMP_DIR/lib/hello.cpp" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "hello.cpp not found in lib/"
fi

# Verify CMakeLists.txt references lib/ instead of src/
if grep -q "src/hello.cpp" "$TMP_DIR/CMakeLists.txt"; then
    cleanup_dir "$TMP_DIR"
    test_fail "CMakeLists.txt still references src/ instead of lib/"
fi

# Verify Claude Code configuration exists
if [ ! -d "$TMP_DIR/.claude" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail ".claude/ directory not found"
fi

if [ ! -f "$TMP_DIR/CLAUDE.md" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "CLAUDE.md not found"
fi

if [ ! -f "$TMP_DIR/docs/git-msg-tags.md" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "docs/git-msg-tags.md not found"
fi

if [ ! -f "$TMP_DIR/.claude/settings.json" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail ".claude/settings.json not found"
fi

# Building C++ SDK with lib/
make -C "$TMP_DIR" build

# Running C++ SDK tests with lib/
make -C "$TMP_DIR" test

cleanup_dir "$TMP_DIR"
test_pass "Custom source path (lib/) works"
