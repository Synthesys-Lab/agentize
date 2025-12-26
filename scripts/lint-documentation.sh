#!/bin/bash

# Documentation linter for pre-commit hook
# Validates that all folders, source files, and tests have proper documentation

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get repository root
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Track if any errors were found
ERRORS_FOUND=0

# Arrays to store missing documentation
declare -a MISSING_FOLDER_READMES
declare -a MISSING_SOURCE_DOCS
declare -a MISSING_TEST_DOCS

echo "Running documentation linter..."
echo ""

# Function to check if a file exists
file_exists() {
    [ -f "$1" ]
}

# Function to check if directory should be excluded
should_exclude_dir() {
    local dir="$1"

    # Exclude hidden directories (starting with .)
    if [[ "$dir" == .* ]]; then
        return 0  # true, should exclude
    fi

    # Exclude common build/generated directories and template directories
    case "$dir" in
        node_modules|build|dist|__pycache__|.git|.venv|venv|templates|.milestones|trees)
            return 0  # true, should exclude
            ;;
        templates/*|.milestones/*|trees/*)
            return 0  # true, should exclude subdirectories too
            ;;
    esac

    return 1  # false, should not exclude
}

# Function to check if file should be excluded
should_exclude_file() {
    local file="$1"

    # Exclude files in hidden directories
    if [[ "$file" == .*/* ]]; then
        return 0  # true, should exclude
    fi

    # Exclude files in templates and .milestones directories
    if [[ "$file" == templates/* ]] || [[ "$file" == .milestones/* ]]; then
        return 0  # true, should exclude
    fi

    # Exclude generated or temporary files
    case "$file" in
        *.pyc|*.pyo|*.o|*.so|*.dylib|*.a)
            return 0  # true, should exclude
            ;;
    esac

    return 1  # false, should not exclude
}

# Function to check if test file has inline documentation
has_inline_test_docs() {
    local test_file="$1"

    # For shell test files, look for comment patterns indicating test documentation
    if [[ "$test_file" == *.sh ]]; then
        # Check for common test documentation patterns
        if grep -qE "^# Test( [0-9]+)?:" "$test_file" 2>/dev/null; then
            return 0  # true, has inline docs
        fi
        if grep -qE "^# Purpose:|^# Expected:" "$test_file" 2>/dev/null; then
            return 0  # true, has inline docs
        fi
        # Check for function comments (test functions)
        if grep -qE "^# test_.*\(\)" "$test_file" 2>/dev/null; then
            return 0  # true, has inline docs
        fi
    fi

    return 1  # false, no inline docs found
}

# Get list of staged files (for pre-commit) or all tracked files (for manual run)
if git diff --cached --quiet; then
    # No staged files, run on all tracked files (manual invocation)
    STAGED_FILES=$(git ls-files)
    MODE="manual"
else
    # Has staged files, run only on those (pre-commit invocation)
    STAGED_FILES=$(git diff --cached --name-only)
    MODE="pre-commit"
fi

# Check 1: Find folders without README.md
echo "Checking folder documentation..."

# Extract unique directories from staged files
DIRECTORIES=$(echo "$STAGED_FILES" | xargs -n1 dirname | sort -u)

for dir in $DIRECTORIES; do
    # Skip if should be excluded
    if should_exclude_dir "$dir"; then
        continue
    fi

    # Skip current directory marker
    if [ "$dir" = "." ]; then
        continue
    fi

    # Check if README.md exists
    if ! file_exists "$REPO_ROOT/$dir/README.md"; then
        MISSING_FOLDER_READMES+=("$dir/README.md")
        ERRORS_FOUND=1
    fi
done

# Check 2: Find source files without .md companions
echo "Checking source code documentation..."

# Source file extensions that require documentation
SOURCE_EXTENSIONS=("py" "c" "cpp" "cxx" "cc")

for file in $STAGED_FILES; do
    # Skip if should be excluded
    if should_exclude_file "$file"; then
        continue
    fi

    # Check if file has a source extension
    for ext in "${SOURCE_EXTENSIONS[@]}"; do
        if [[ "$file" == *."$ext" ]]; then
            # Get the base name without extension
            base="${file%.*}"
            md_file="${base}.md"

            if ! file_exists "$REPO_ROOT/$md_file"; then
                MISSING_SOURCE_DOCS+=("$md_file")
                ERRORS_FOUND=1
            fi
            break
        fi
    done
done

# Check 3: Find test files without documentation
echo "Checking test documentation..."

for file in $STAGED_FILES; do
    # Skip if should be excluded
    if should_exclude_file "$file"; then
        continue
    fi

    # Check if file is a test file (in tests/ directory or named test_*.sh)
    if [[ "$file" == tests/* ]] || [[ "$file" == test_*.sh ]]; then
        # For shell scripts, check for inline documentation first
        if [[ "$file" == *.sh ]]; then
            if has_inline_test_docs "$REPO_ROOT/$file"; then
                continue  # Has inline docs, OK
            fi
        fi

        # No inline docs, check for companion .md file
        base="${file%.*}"
        md_file="${base}.md"

        if ! file_exists "$REPO_ROOT/$md_file"; then
            MISSING_TEST_DOCS+=("$md_file (or add inline documentation)")
            ERRORS_FOUND=1
        fi
    fi
done

# Report results
echo ""

if [ $ERRORS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ Documentation linting passed!${NC}"
    echo ""
    exit 0
fi

# Print errors
echo -e "${RED}✗ Documentation linting failed!${NC}"
echo ""

if [ ${#MISSING_FOLDER_READMES[@]} -gt 0 ]; then
    echo -e "${YELLOW}Missing folder README.md files:${NC}"
    for readme in "${MISSING_FOLDER_READMES[@]}"; do
        echo "  - $readme"
    done
    echo ""
fi

if [ ${#MISSING_SOURCE_DOCS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Missing source code documentation files:${NC}"
    for doc in "${MISSING_SOURCE_DOCS[@]}"; do
        echo "  - $doc"
    done
    echo ""
fi

if [ ${#MISSING_TEST_DOCS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Missing test documentation:${NC}"
    for doc in "${MISSING_TEST_DOCS[@]}"; do
        echo "  - $doc"
    done
    echo ""
fi

echo "Please add the missing documentation files before committing."
echo "For milestone commits, you can bypass this check with: git commit --no-verify"
echo ""

exit 1
