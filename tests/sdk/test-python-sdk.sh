#!/bin/bash

# Source shared test helper
source "$(dirname "$0")/../common.sh"

echo "======================================"
echo "Testing Python SDK"
echo "======================================"
echo ""

# Test: Default Python SDK
echo ">>> Test: Creating Python SDK project"
TMP_DIR="$PROJECT_ROOT/.tmp/python-sdk-test"
rm -rf "$TMP_DIR"

echo "Creating Python SDK..."
(
    source "$PROJECT_ROOT/src/cli/lol.sh"
    lol_cmd_init "$TMP_DIR" "test_python_sdk" "python"
)

# Verify test_python_sdk/ directory exists (project_name renamed)
if [ ! -d "$TMP_DIR/test_python_sdk" ]; then
    echo "Error: test_python_sdk/ directory not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR/test_python_sdk/__init__.py" ]; then
    echo "Error: __init__.py not found in test_python_sdk/!"
    exit 1
fi

# Verify bootstrap.sh was deleted
if [ -f "$TMP_DIR/bootstrap.sh" ]; then
    echo "Error: bootstrap.sh should have been deleted!"
    exit 1
fi

# Verify Claude Code configuration exists
if [ ! -d "$TMP_DIR/.claude" ]; then
    echo "Error: .claude/ directory not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR/CLAUDE.md" ]; then
    echo "Error: CLAUDE.md not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR/docs/git-msg-tags.md" ]; then
    echo "Error: docs/git-msg-tags.md not found!"
    exit 1
fi

if [ ! -f "$TMP_DIR/.claude/settings.json" ]; then
    echo "Error: .claude/settings.json not found!"
    exit 1
fi

if [ ! -d "$TMP_DIR/.claude/skills/commit-msg" ]; then
    echo "Error: .claude/skills/commit-msg/ not found!"
    exit 1
fi

if [ ! -d "$TMP_DIR/.claude/skills/open-issue" ]; then
    echo "Error: .claude/skills/open-issue/ not found!"
    exit 1
fi

# Verify Python-specific tag in git-msg-tags.md
if ! grep -q "deps.*Python dependency" "$TMP_DIR/docs/git-msg-tags.md"; then
    echo "Error: Python-specific 'deps' tag not found in git-msg-tags.md!"
    exit 1
fi

# Verify C/C++ build tag was removed
if grep -q "build.*CMakeLists" "$TMP_DIR/docs/git-msg-tags.md"; then
    echo "Error: C/C++-specific 'build' tag should not be in Python git-msg-tags.md!"
    exit 1
fi

# Verify test file was updated to use correct module name
if grep -q "import project_name" "$TMP_DIR/tests/test_main.py"; then
    echo "Error: tests/test_main.py still references 'project_name' instead of 'test_python_sdk'!"
    exit 1
fi

echo "Generating setup script..."
# Note: This tests the SDK's per-project setup.sh generation, not the agentize repo's cross-project setup
make -C "$TMP_DIR" setup

# Verify setup.sh was created
if [ ! -f "$TMP_DIR/setup.sh" ]; then
    echo "Error: setup.sh not generated!"
    exit 1
fi

# Verify setup.sh sets PYTHONPATH
if ! grep -q "PYTHONPATH" "$TMP_DIR/setup.sh"; then
    echo "Error: setup.sh does not set PYTHONPATH!"
    exit 1
fi

echo "Sourcing setup.sh and running tests..."
(
    cd "$TMP_DIR"
    source ./setup.sh > /dev/null
    make test
)

echo "✓ Test passed: Python SDK works correctly"
echo ""

echo "======================================"
echo "All Python SDK tests completed successfully!"
echo "======================================"
echo "Test project remains at:"
echo "  - $TMP_DIR"
