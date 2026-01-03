#!/usr/bin/env bash
# Test: Default C SDK source path (src/)

source "$(dirname "$0")/common.sh"

test_info "Default C SDK source path (src/)"

TMP_DIR=$(make_temp_dir "c-sdk-test-src")

# Creating C SDK with default source path
(
    export AGENTIZE_PROJECT_NAME="test-c-sdk-src"
    export AGENTIZE_PROJECT_PATH="$TMP_DIR"
    export AGENTIZE_PROJECT_LANG="c"
    "$PROJECT_ROOT/scripts/agentize-init.sh"
)

# Verify src/ directory exists
if [ ! -d "$TMP_DIR/src" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "src/ directory not found"
fi

if [ ! -f "$TMP_DIR/src/hello.c" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail "hello.c not found in src/"
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

if [ ! -d "$TMP_DIR/.claude/skills/commit-msg" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail ".claude/skills/commit-msg/ not found"
fi

if [ ! -d "$TMP_DIR/.claude/skills/open-issue" ]; then
    cleanup_dir "$TMP_DIR"
    test_fail ".claude/skills/open-issue/ not found"
fi

# Verify C-specific tag in git-msg-tags.md
if ! grep -q "build.*CMakeLists" "$TMP_DIR/docs/git-msg-tags.md"; then
    cleanup_dir "$TMP_DIR"
    test_fail "C-specific 'build' tag not found in git-msg-tags.md"
fi

# Verify Python deps tag was removed
if grep -q "deps.*Python" "$TMP_DIR/docs/git-msg-tags.md"; then
    cleanup_dir "$TMP_DIR"
    test_fail "Python-specific 'deps' tag should not be in C git-msg-tags.md"
fi

# Building C SDK with src/
make -C "$TMP_DIR" build

# Running C SDK tests with src/
make -C "$TMP_DIR" test

cleanup_dir "$TMP_DIR"
test_pass "Default source path (src/) works"
