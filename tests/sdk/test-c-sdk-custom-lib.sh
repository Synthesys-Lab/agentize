#!/usr/bin/env bash
# Test: Custom C SDK source path (lib/)

source "$(dirname "$0")/../common.sh"

test_info "Custom C SDK source path (lib/)"

TMP_DIR=$(make_temp_dir "c-sdk-test-lib")

# Creating C SDK with custom source path (lib/)
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_init "$TMP_DIR" "test-c-sdk-lib" "c" "lib"
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

if [ ! -f "$TMP_DIR/lib/hello.c" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "hello.c not found in lib/"
fi

# Verify CMakeLists.txt references lib/ instead of src/
if grep -q "src/hello.c" "$TMP_DIR/CMakeLists.txt"; then
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

# Building C SDK with lib/
make -C "$TMP_DIR" build

# Running C SDK tests with lib/
make -C "$TMP_DIR" test

cleanup_dir "$TMP_DIR"
test_pass "Custom source path (lib/) works"
