#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================"
echo "Testing Agentize Mode Validation"
echo "======================================"
echo ""

# Test 1: init mode with non-existent directory
echo ">>> Test 1: init mode with non-existent directory"
TMP_DIR_1="$PROJECT_ROOT/.tmp/mode-test-1"
rm -rf "$TMP_DIR_1"

echo "Creating SDK in non-existent directory..."
"$PROJECT_ROOT/scripts/lol-cli.sh" init --name "test_mode_1" --path "$TMP_DIR_1" --lang python

if [ ! -d "$TMP_DIR_1" ]; then
    echo "Error: Directory was not created!"
    exit 1
fi

if [ ! -d "$TMP_DIR_1/.claude" ]; then
    echo "Error: SDK structure not created!"
    exit 1
fi

echo "✓ Test 1 passed: init mode creates directory and SDK structure"
echo ""

# Test 2: init mode with empty existing directory
echo ">>> Test 2: init mode with empty existing directory"
TMP_DIR_2="$PROJECT_ROOT/.tmp/mode-test-2"
rm -rf "$TMP_DIR_2"
mkdir -p "$TMP_DIR_2"

echo "Creating SDK in empty existing directory..."
"$PROJECT_ROOT/scripts/lol-cli.sh" init --name "test_mode_2" --path "$TMP_DIR_2" --lang python

if [ ! -d "$TMP_DIR_2/.claude" ]; then
    echo "Error: SDK structure not created!"
    exit 1
fi

echo "✓ Test 2 passed: init mode works with empty existing directory"
echo ""

# Test 3: init mode with non-empty existing directory (should fail)
echo ">>> Test 3: init mode with non-empty existing directory (should fail)"
TMP_DIR_3="$PROJECT_ROOT/.tmp/mode-test-3"
rm -rf "$TMP_DIR_3"
mkdir -p "$TMP_DIR_3"
touch "$TMP_DIR_3/existing-file.txt"

echo "Attempting to create SDK in non-empty directory (should fail)..."
if "$PROJECT_ROOT/scripts/lol-cli.sh" init --name "test_mode_3" --path "$TMP_DIR_3" --lang python 2>&1 | grep -q "exists and is not empty"; then
    echo "✓ Test 3 passed: init mode correctly rejects non-empty directory"
else
    echo "Error: init mode should have rejected non-empty directory!"
    exit 1
fi
echo ""

# Test 4: update mode with non-existent directory (should fail)
echo ">>> Test 4: update mode with non-existent directory (should fail)"
TMP_DIR_4="$PROJECT_ROOT/.tmp/mode-test-4"
rm -rf "$TMP_DIR_4"

echo "Attempting to update non-existent directory (should fail)..."
if "$PROJECT_ROOT/scripts/lol-cli.sh" update --path "$TMP_DIR_4" 2>&1 | grep -q "does not exist"; then
    echo "✓ Test 4 passed: update mode correctly rejects non-existent directory"
else
    echo "Error: update mode should have rejected non-existent directory!"
    exit 1
fi
echo ""

# Test 5: update mode with directory without SDK structure (should create .claude/)
echo ">>> Test 5: update mode with directory without SDK structure (should create .claude/)"
TMP_DIR_5="$PROJECT_ROOT/.tmp/mode-test-5"
rm -rf "$TMP_DIR_5"
mkdir -p "$TMP_DIR_5"
touch "$TMP_DIR_5/some-file.txt"

echo "Updating directory without SDK structure (should create .claude/)..."
"$PROJECT_ROOT/scripts/lol-cli.sh" update --path "$TMP_DIR_5"

# Verify .claude/ was created
if [ ! -d "$TMP_DIR_5/.claude" ]; then
    echo "Error: .claude/ directory was not created!"
    exit 1
fi

# Verify docs/git-msg-tags.md was created
if [ ! -f "$TMP_DIR_5/docs/git-msg-tags.md" ]; then
    echo "Error: docs/git-msg-tags.md was not created!"
    exit 1
fi

# Verify no backup was created (since .claude/ didn't exist before)
if [ -d "$TMP_DIR_5/.claude.backup" ]; then
    echo "Error: Backup should not be created when .claude/ is newly created!"
    exit 1
fi

echo "✓ Test 5 passed: update mode creates .claude/ and syncs files when missing"
echo ""

# Test 6: update mode with valid SDK structure (should succeed)
echo ">>> Test 6: update mode with valid SDK structure (should succeed)"
TMP_DIR_6="$PROJECT_ROOT/.tmp/mode-test-6"
rm -rf "$TMP_DIR_6"

echo "First creating a valid SDK..."
"$PROJECT_ROOT/scripts/lol-cli.sh" init --name "test_mode_6" --path "$TMP_DIR_6" --lang python

# Modify a file in .claude/ to verify backup
echo "# Modified by test" >> "$TMP_DIR_6/.claude/settings.json"

echo "Now updating the SDK..."
"$PROJECT_ROOT/scripts/lol-cli.sh" update --path "$TMP_DIR_6"

# Verify backup was created
if [ ! -d "$TMP_DIR_6/.claude.backup" ]; then
    echo "Error: Backup directory not created during update!"
    exit 1
fi

# Verify settings.json was updated (shouldn't contain test modification)
if grep -q "Modified by test" "$TMP_DIR_6/.claude/settings.json"; then
    echo "Error: settings.json was not updated!"
    exit 1
fi

# Verify backup contains the modification
if ! grep -q "Modified by test" "$TMP_DIR_6/.claude.backup/settings.json"; then
    echo "Error: Backup doesn't contain previous version!"
    exit 1
fi

echo "✓ Test 6 passed: update mode correctly updates valid SDK structure"
echo ""

# Test 7: update mode preserves user-added files
echo ">>> Test 7: update mode preserves user-added custom files"
TMP_DIR_7="$PROJECT_ROOT/.tmp/mode-test-7"
rm -rf "$TMP_DIR_7"

echo "First creating a valid SDK..."
"$PROJECT_ROOT/scripts/lol-cli.sh" init --name "test_mode_7" --path "$TMP_DIR_7" --lang python

# Add custom user files
mkdir -p "$TMP_DIR_7/.claude/skills/my-custom-skill"
echo "# My Custom Skill" > "$TMP_DIR_7/.claude/skills/my-custom-skill/SKILL.md"
mkdir -p "$TMP_DIR_7/.claude/commands/my-custom-command"
echo "# My Custom Command" > "$TMP_DIR_7/.claude/commands/my-custom-command/COMMAND.md"

echo "Running update to sync template files..."
"$PROJECT_ROOT/scripts/lol-cli.sh" update --path "$TMP_DIR_7"

# Verify custom user files still exist
if [ ! -f "$TMP_DIR_7/.claude/skills/my-custom-skill/SKILL.md" ]; then
    echo "Error: Custom skill file was deleted during update!"
    exit 1
fi

if [ ! -f "$TMP_DIR_7/.claude/commands/my-custom-command/COMMAND.md" ]; then
    echo "Error: Custom command file was deleted during update!"
    exit 1
fi

# Verify template files were updated correctly (settings.json should exist)
if [ ! -f "$TMP_DIR_7/.claude/settings.json" ]; then
    echo "Error: Template file settings.json was not updated!"
    exit 1
fi

echo "✓ Test 7 passed: update mode preserves user-added files while updating templates"
echo ""

# Test 8: metadata-first language resolution
echo ">>> Test 8: update mode uses metadata-first language resolution"
TMP_DIR_8="$PROJECT_ROOT/.tmp/mode-test-8"
rm -rf "$TMP_DIR_8"

echo "Creating SDK with Python..."
"$PROJECT_ROOT/scripts/lol-cli.sh" init --name "test_mode_8" --path "$TMP_DIR_8" --lang python

# Verify .agentize.yaml was created with project.lang: python
if ! grep -q "lang: python" "$TMP_DIR_8/.agentize.yaml"; then
    echo "Error: .agentize.yaml doesn't contain 'lang: python'!"
    exit 1
fi

# Remove git-msg-tags.md to trigger recreation
rm -f "$TMP_DIR_8/docs/git-msg-tags.md"

echo "Running update to recreate git-msg-tags.md using metadata..."
"$PROJECT_ROOT/scripts/lol-cli.sh" update --path "$TMP_DIR_8"

# Verify git-msg-tags.md was recreated with Python template (has deps, no build)
if [ ! -f "$TMP_DIR_8/docs/git-msg-tags.md" ]; then
    echo "Error: git-msg-tags.md was not recreated!"
    exit 1
fi

if ! grep -q "deps" "$TMP_DIR_8/docs/git-msg-tags.md"; then
    echo "Error: git-msg-tags.md should have Python-specific 'deps' tag!"
    exit 1
fi

if grep -q "build.*CMakeLists" "$TMP_DIR_8/docs/git-msg-tags.md"; then
    echo "Error: git-msg-tags.md should not have C/C++-specific 'build' tag!"
    exit 1
fi

echo "✓ Test 8 passed: update mode uses metadata-first language resolution"
echo ""

echo "======================================"
echo "All Agentize mode tests completed successfully!"
echo "======================================"
echo "Test artifacts remain at:"
echo "  - $PROJECT_ROOT/.tmp/mode-test-*"
echo ""
