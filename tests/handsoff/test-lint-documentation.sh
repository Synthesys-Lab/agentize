#!/usr/bin/env bash
# Test: Documentation linter correctly handles skill directories with SKILL.md
# Purpose: Verify lint-documentation.sh accepts SKILL.md in skill dirs and requires README.md elsewhere
# Expected: All 4 test cases pass

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/lint-documentation.sh"

# Run test in subshell with clean git environment
set +e
(
  # Unset all GIT_* environment variables to avoid pre-commit hook interference
  for var in $(env | grep '^GIT_' | cut -d= -f1); do
    unset "$var"
  done

  # Colors for output
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m' # No Color

  >&2 echo "=== Documentation Linter Test ==="

  # Create a temporary git repository for testing
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  git init > /dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Copy linter script to temp repo
  cp "$LINTER" ./lint-documentation.sh

  # Test 1: Skill directory with SKILL.md only passes
  >&2 echo ""
  >&2 echo "Test 1: Skill directory with SKILL.md only passes"
  mkdir -p .claude/skills/test-skill
  cat > .claude/skills/test-skill/SKILL.md << 'EOF'
# Test Skill
Test skill documentation.
EOF
  git add .claude/skills/test-skill/SKILL.md

  if ./lint-documentation.sh > /dev/null 2>&1; then
    >&2 echo -e "${GREEN}PASS: Skill directory with SKILL.md passes${NC}"
  else
    >&2 echo -e "${RED}FAIL: Skill directory with SKILL.md should pass${NC}"
    cd "$SCRIPT_DIR"
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  # Clean up for next test
  git reset > /dev/null 2>&1
  rm -rf .claude

  # Test 2: Skill directory missing both SKILL.md and README.md fails
  >&2 echo ""
  >&2 echo "Test 2: Skill directory missing both SKILL.md and README.md fails"
  mkdir -p .claude/skills/empty-skill
  touch .claude/skills/empty-skill/command.sh
  git add .claude/skills/empty-skill/command.sh

  if ./lint-documentation.sh > /dev/null 2>&1; then
    >&2 echo -e "${RED}FAIL: Skill directory without SKILL.md or README.md should fail${NC}"
    cd "$SCRIPT_DIR"
    rm -rf "$TEMP_DIR"
    exit 1
  else
    >&2 echo -e "${GREEN}PASS: Skill directory without documentation fails${NC}"
  fi

  # Clean up for next test
  git reset > /dev/null 2>&1
  rm -rf .claude

  # Test 3: Non-skill directory still requires README.md
  >&2 echo ""
  >&2 echo "Test 3: Non-skill directory still requires README.md"
  mkdir -p src/utils
  touch src/utils/helper.txt
  git add src/utils/helper.txt

  if ./lint-documentation.sh > /dev/null 2>&1; then
    >&2 echo -e "${RED}FAIL: Non-skill directory without README.md should fail${NC}"
    cd "$SCRIPT_DIR"
    rm -rf "$TEMP_DIR"
    exit 1
  else
    >&2 echo -e "${GREEN}PASS: Non-skill directory without README.md fails${NC}"
  fi

  # Clean up for next test
  git reset > /dev/null 2>&1
  rm -rf src

  # Test 4: Hidden non-skill directories remain excluded
  >&2 echo ""
  >&2 echo "Test 4: Hidden non-skill directories remain excluded"
  mkdir -p .hidden/subdir
  touch .hidden/subdir/file.txt
  git add .hidden/subdir/file.txt

  if ./lint-documentation.sh > /dev/null 2>&1; then
    >&2 echo -e "${GREEN}PASS: Hidden non-skill directories excluded${NC}"
  else
    >&2 echo -e "${RED}FAIL: Hidden directories should be excluded${NC}"
    cd "$SCRIPT_DIR"
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  # Clean up temp directory
  cd "$SCRIPT_DIR"
  rm -rf "$TEMP_DIR"

  >&2 echo ""
  >&2 echo -e "${GREEN}All documentation linter tests passed!${NC}"

  exit 0
)
exit_code=$?
>&2 echo ""
exit $exit_code
