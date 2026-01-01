#!/usr/bin/env bash
# Test for documentation linter
# Verifies linter correctly handles skill directories with SKILL.md

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/lint-documentation.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=== Documentation Linter Test ==="

# Create a temporary git repository for testing
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
git init > /dev/null 2>&1
git config user.email "test@example.com"
git config user.name "Test User"

# Copy linter script to temp repo
cp "$LINTER" ./lint-documentation.sh

# Test 1: Skill directory with SKILL.md only passes
echo ""
echo "Test 1: Skill directory with SKILL.md only passes"
mkdir -p .claude/skills/test-skill
cat > .claude/skills/test-skill/SKILL.md << 'EOF'
# Test Skill
Test skill documentation.
EOF
git add .claude/skills/test-skill/SKILL.md

if ./lint-documentation.sh > /dev/null 2>&1; then
  echo -e "${GREEN}PASS: Skill directory with SKILL.md passes${NC}"
else
  echo -e "${RED}FAIL: Skill directory with SKILL.md should pass${NC}"
  cd "$SCRIPT_DIR"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Clean up for next test
git reset > /dev/null 2>&1
rm -rf .claude

# Test 2: Skill directory missing both SKILL.md and README.md fails
echo ""
echo "Test 2: Skill directory missing both SKILL.md and README.md fails"
mkdir -p .claude/skills/empty-skill
touch .claude/skills/empty-skill/command.sh
git add .claude/skills/empty-skill/command.sh

if ./lint-documentation.sh > /dev/null 2>&1; then
  echo -e "${RED}FAIL: Skill directory without SKILL.md or README.md should fail${NC}"
  cd "$SCRIPT_DIR"
  rm -rf "$TEMP_DIR"
  exit 1
else
  echo -e "${GREEN}PASS: Skill directory without documentation fails${NC}"
fi

# Clean up for next test
git reset > /dev/null 2>&1
rm -rf .claude

# Test 3: Non-skill directory still requires README.md
echo ""
echo "Test 3: Non-skill directory still requires README.md"
mkdir -p src/utils
touch src/utils/helper.txt
git add src/utils/helper.txt

if ./lint-documentation.sh > /dev/null 2>&1; then
  echo -e "${RED}FAIL: Non-skill directory without README.md should fail${NC}"
  cd "$SCRIPT_DIR"
  rm -rf "$TEMP_DIR"
  exit 1
else
  echo -e "${GREEN}PASS: Non-skill directory without README.md fails${NC}"
fi

# Clean up for next test
git reset > /dev/null 2>&1
rm -rf src

# Test 4: Hidden non-skill directories remain excluded
echo ""
echo "Test 4: Hidden non-skill directories remain excluded"
mkdir -p .hidden/subdir
touch .hidden/subdir/file.txt
git add .hidden/subdir/file.txt

if ./lint-documentation.sh > /dev/null 2>&1; then
  echo -e "${GREEN}PASS: Hidden non-skill directories excluded${NC}"
else
  echo -e "${RED}FAIL: Hidden directories should be excluded${NC}"
  cd "$SCRIPT_DIR"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Clean up temp directory
cd "$SCRIPT_DIR"
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}All documentation linter tests passed!${NC}"
