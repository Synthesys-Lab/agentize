#!/bin/bash

set -e

# Get project root using shell-neutral approach
PROJECT_ROOT="${AGENTIZE_HOME:-$(git rev-parse --show-toplevel 2>/dev/null)}"
if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: Cannot determine project root. Set AGENTIZE_HOME or run from git repo."
  exit 1
fi

echo "======================================"
echo "Testing C SDK with different SOURCE_PATH configurations"
echo "======================================"
echo ""

# Test 1: Default source path (src/)
echo ">>> Test 1: Default source path (src/)"
TMP_DIR_SRC="$PROJECT_ROOT/.tmp/c-sdk-test-src"
rm -rf "$TMP_DIR_SRC"

echo "Creating C SDK with default source path..."
(
    export AGENTIZE_PROJECT_NAME="test-c-sdk-src"
    export AGENTIZE_PROJECT_PATH="$TMP_DIR_SRC"
    export AGENTIZE_PROJECT_LANG="c"
    "$PROJECT_ROOT/scripts/agentize-init.sh"
)

# Verify src/ directory exists
if [ ! -d "$TMP_DIR_SRC/src" ]; then
    echo "Error: src/ directory not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR_SRC/src/hello.c" ]; then
    echo "Error: hello.c not found in src/!"
    exit 1
fi

# Verify Claude Code configuration exists
if [ ! -d "$TMP_DIR_SRC/.claude" ]; then
    echo "Error: .claude/ directory not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR_SRC/CLAUDE.md" ]; then
    echo "Error: CLAUDE.md not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR_SRC/docs/git-msg-tags.md" ]; then
    echo "Error: docs/git-msg-tags.md not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR_SRC/.claude/settings.json" ]; then
    echo "Error: .claude/settings.json not found!"
    exit 1
fi

if [ ! -d "$TMP_DIR_SRC/.claude/skills/commit-msg" ]; then
    echo "Error: .claude/skills/commit-msg/ not found!"
    exit 1
fi

if [ ! -d "$TMP_DIR_SRC/.claude/skills/open-issue" ]; then
    echo "Error: .claude/skills/open-issue/ not found!"
    exit 1
fi

# Verify C-specific tag in git-msg-tags.md
if ! grep -q "build.*CMakeLists" "$TMP_DIR_SRC/docs/git-msg-tags.md"; then
    echo "Error: C-specific 'build' tag not found in git-msg-tags.md!"
    exit 1
fi

# Verify Python deps tag was removed
if grep -q "deps.*Python" "$TMP_DIR_SRC/docs/git-msg-tags.md"; then
    echo "Error: Python-specific 'deps' tag should not be in C git-msg-tags.md!"
    exit 1
fi

echo "Building C SDK with src/..."
make -C "$TMP_DIR_SRC" build

echo "Running C SDK tests with src/..."
make -C "$TMP_DIR_SRC" test

echo "✓ Test 1 passed: Default source path (src/) works"
echo ""

# Test 2: Custom source path (lib/)
echo ">>> Test 2: Custom source path (lib/)"
TMP_DIR_LIB="$PROJECT_ROOT/.tmp/c-sdk-test-lib"
rm -rf "$TMP_DIR_LIB"

echo "Creating C SDK with custom source path (lib/)..."
(
    export AGENTIZE_PROJECT_NAME="test-c-sdk-lib"
    export AGENTIZE_PROJECT_PATH="$TMP_DIR_LIB"
    export AGENTIZE_PROJECT_LANG="c"
    export AGENTIZE_SOURCE_PATH="lib"
    "$PROJECT_ROOT/scripts/agentize-init.sh"
)

# Verify lib/ directory exists and src/ does not
if [ -d "$TMP_DIR_LIB/src" ]; then
    echo "Error: src/ directory should not exist when using custom SOURCE_PATH!"
    exit 1
fi

if [ ! -d "$TMP_DIR_LIB/lib" ]; then
    echo "Error: lib/ directory not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR_LIB/lib/hello.c" ]; then
    echo "Error: hello.c not found in lib/!"
    exit 1
fi

# Verify CMakeLists.txt references lib/ instead of src/
if grep -q "src/hello.c" "$TMP_DIR_LIB/CMakeLists.txt"; then
    echo "Error: CMakeLists.txt still references src/ instead of lib/!"
    exit 1
fi

# Verify Claude Code configuration exists
if [ ! -d "$TMP_DIR_LIB/.claude" ]; then
    echo "Error: .claude/ directory not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR_LIB/CLAUDE.md" ]; then
    echo "Error: CLAUDE.md not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR_LIB/docs/git-msg-tags.md" ]; then
    echo "Error: docs/git-msg-tags.md not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR_LIB/.claude/settings.json" ]; then
    echo "Error: .claude/settings.json not found!"
    exit 1
fi

echo "Building C SDK with lib/..."
make -C "$TMP_DIR_LIB" build

echo "Running C SDK tests with lib/..."
make -C "$TMP_DIR_LIB" test

echo "✓ Test 2 passed: Custom source path (lib/) works"
echo ""

echo "======================================"
echo "All C SDK tests completed successfully!"
echo "======================================"
echo "Test projects remain at:"
echo "  - Default (src/): $TMP_DIR_SRC"
echo "  - Custom (lib/):  $TMP_DIR_LIB"
