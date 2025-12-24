---
name: review-standard
description: Systematic code review skill checking documentation quality and promoting code reuse
---

# Review Standard

This skill instructs AI agents on how to perform comprehensive code reviews before merging
changes to the main branch. It ensures quality, consistency, and adherence to project
documentation and code reuse standards.

## Review Philosophy

Effective code review is:
- **Systematic**: Follow a consistent process across all reviews
- **Standards-based**: Enforce documentation standards defined in `document-guideline` skill
- **Reuse-focused**: Prevent reinventing the wheel by identifying existing utilities
- **Actionable**: Provide specific, implementable recommendations
- **Context-aware**: Understand the change within the broader codebase architecture

### Review Objectives

Every review must assess:
1. **Documentation Quality**: Are changes properly documented per `document-guideline` standards?
2. **Code Quality & Reuse**: Does the code follow best practices and leverage existing utilities?

The review process is designed to catch issues before merge, not to block progress. Reviews
provide recommendations - final merge decisions remain with maintainers.

## Review Process Overview

When the `/code-review` command is invoked, agents must:

1. **Gather context**: Get list of changed files and full diff
2. **Phase 1 - Documentation Review**: Validate documentation completeness and quality
3. **Phase 2 - Code Quality Review**: Assess code quality and reuse opportunities
4. **Generate report**: Provide structured, actionable feedback

## Phase 1: Documentation Quality Review

This phase validates that all changes comply with the `document-guideline` skill standards.

### Step 1: Identify Changed Files

Get the list of all changed files:

```bash
git diff --name-only main...HEAD
```

Categorize files by type:
- **Source code files**: `.py`, `.c`, `.cpp`, `.cxx`, `.cc`, etc.
- **Documentation files**: `.md` files
- **Test files**: `test_*.sh`, `*_test.py`, etc.
- **Other files**: Configuration, data files, etc.

### Step 2: Validate Folder README.md Files

**Standard**: Every folder (except hidden folders) must have a `README.md` file.

**Check**:
```bash
# Get list of directories with changes
git diff --name-only main...HEAD | xargs -n1 dirname | sort -u

# For each directory, check if README.md exists
```

**Common issues**:
- New folder created without `README.md`
- Existing folder's `README.md` not updated to reflect new files

**Example finding**:
```
❌ Missing folder documentation
   claude/skills/new-skill/ - No README.md found

   Recommendation: Create README.md documenting:
   - Folder purpose (what is this skill for?)
   - Key files and their roles
   - Integration with other skills
```

### Step 3: Validate Source Code Interface Documentation

**Standard**: Every source code file must have a corresponding `.md` file.

**File types requiring documentation**:
- Python: `*.py` → `*.md`
- C/C++: `*.c`, `*.cpp`, `*.cxx`, `*.cc` → `*.md`

**Check**:
```bash
# For each source file in changes, verify .md file exists
git diff --name-only main...HEAD | grep -E '\.(py|c|cpp|cxx|cc)$'

# For each match, check if corresponding .md exists
```

**Review .md content for**:
1. **External Interfaces section**: Documents public APIs
   - Function signatures
   - Expected inputs/outputs
   - Error conditions

2. **Internal Helpers section**: Documents private implementation
   - Internal functions
   - Helper utilities
   - Complex algorithms

**Common issues**:
- Source file exists but `.md` file missing
- `.md` file exists but doesn't document all public functions
- Interface documentation doesn't match actual implementation

**Example finding**:
```
❌ Missing interface documentation
   src/utils/validator.py - No validator.md found

   Recommendation: Create validator.md with:
   - External Interface: validate_input(), validate_config() signatures
   - Internal Helpers: _check_type(), _sanitize_value() descriptions

❌ Incomplete interface documentation
   src/api/handler.md - Missing documentation for handle_request() function

   Recommendation: Add handle_request() to External Interface section:
   - Parameters: request object structure
   - Return value: response object or error
   - Error conditions: invalid request format, auth failures
```

### Step 4: Validate Test Documentation

**Standard**: Every test file must have documentation explaining what it tests.

**Acceptable formats**:
1. Inline comments within test file (preferred for simple tests)
2. Companion `.md` file (for complex test suites)

**Check**:
```bash
# Get test files from changes
git diff --name-only main...HEAD | grep -E '(^test_|_test\.(py|sh))'

# For bash tests, check for:
# - Inline comments matching pattern: "# Test N:" or "# Test:"
# - OR companion .md file exists

# For Python tests, check for:
# - Docstrings in test functions
# - OR companion .md file exists
```

**Common issues**:
- Test file has no comments or documentation
- Test file has generic comments but doesn't explain what's being tested
- Complex test suite lacks overview documentation

**Example finding**:
```
❌ Missing test documentation
   tests/test_validation.sh - No inline comments or test_validation.md found

   Recommendation: Add inline comments:
   # Test 1: Validator accepts valid input
   # Expected: Exit code 0, no errors
   test_valid_input() { ... }

   # Test 2: Validator rejects malformed input
   # Expected: Exit code 1, error message contains "malformed"
   test_malformed_input() { ... }
```

### Step 5: Check for High-Level Design Documentation

**Standard**: Architectural changes should have design documentation in `docs/`.

**When design docs are expected**:
- New subsystems or major features
- Architectural changes affecting multiple components
- New workflows or processes
- Significant refactoring

**Check**:
```bash
# Look for design doc references in commit messages
git log main...HEAD --format=%B

# Check if docs/ directory has relevant updates
git diff --name-only main...HEAD | grep '^docs/'
```

**Note**: Design docs are not enforced by linting - requires human judgment.

**Common issues**:
- Major architectural change with no design rationale documented
- New subsystem without overview documentation

**Example finding**:
```
⚠️  Consider adding design documentation
   Changes introduce new authentication subsystem across 5 files

   Recommendation: Consider creating docs/authentication.md to document:
   - Architecture overview
   - Authentication flow
   - Integration points with existing code
   - Security considerations
```

### Step 6: Leverage Documentation Linter

**Tool**: `scripts/lint-documentation.sh`

This script validates structural requirements:
- All folders have `README.md`
- All source files have `.md` companions
- All test files have documentation

**Run linter**:
```bash
./scripts/lint-documentation.sh
```

**Note**: On milestone branches, linter may be bypassed with `git commit --no-verify`.
During review, check if bypass was appropriate:
- ✅ Acceptable: Milestone commit, documentation complete, implementation in progress
- ❌ Not acceptable: Delivery commit, documentation incomplete or missing

**Example finding**:
```
❌ Documentation linter would fail
   Running ./scripts/lint-documentation.sh on this branch would fail:
   - Missing: src/utils/parser.md
   - Missing: claude/commands/README.md

   Recommendation: Add missing documentation before final merge
```

## Phase 2: Code Quality & Reuse Review

This phase assesses code quality and identifies opportunities to reuse existing utilities.

### Step 1: Check for Code Duplication

**Objective**: Find duplicate or similar code within the changes.

**Method**:
```bash
# Get the diff content
git diff main...HEAD

# For each new function/class, search for similar patterns
git grep -n "similar_pattern"
```

**Look for**:
- Similar function names or logic patterns
- Repeated code blocks
- Duplicate validation or error handling logic

**Common issues**:
- New function duplicates existing utility
- Similar logic implemented differently in different files
- Copy-pasted code instead of extracting to shared utility

**Example finding**:
```
❌ Code duplication detected
   src/new_feature.py:42 - Function parse_date() duplicates existing logic

   Existing utility: src/utils/date_parser.py:parse_date()

   Recommendation: Import and use existing parse_date() instead of reimplementing
```

### Step 2: Identify Reuse Opportunities (Local Utilities)

**Objective**: Find existing project utilities that could replace new code.

**Method**:
```bash
# Search for common utility patterns
git grep -n "def validate_"
git grep -n "class.*Parser"
git grep -n "def format_"

# Check common utility locations
ls -la src/utils/
ls -la scripts/
```

**Common utility categories to check**:
- **Validation**: Input validation, type checking, format verification
- **Parsing**: File parsing, data transformation, format conversion
- **Formatting**: Output formatting, string manipulation, templating
- **File operations**: Reading, writing, directory management
- **Git operations**: Diff handling, branch management, commit parsing

**Example finding**:
```
❌ Reinventing the wheel - local utility exists
   src/api/handler.py:67 - Manual JSON validation logic

   Existing utility: src/utils/validators.py:validate_json()

   Recommendation: Replace manual validation with:
   from src.utils.validators import validate_json
   result = validate_json(data)

   Benefits: Consistent error handling, tested utility, less code to maintain
```

### Step 3: Identify Reuse Opportunities (External Libraries)

**Objective**: Find standard libraries or external packages that could replace custom code.

**Method**:
```bash
# Check imports in changed files
git diff main...HEAD | grep -E '^[+]import|^[+]from'

# Look for custom implementations of common tasks
# - Date/time manipulation (use datetime, dateutil)
# - HTTP requests (use requests, urllib)
# - JSON/YAML parsing (use json, yaml)
# - Argument parsing (use argparse)
# - File watching (use watchdog)
```

**Common reinvented wheels**:
- Custom argument parsing instead of `argparse`
- Manual HTTP client instead of `requests`
- Custom date parsing instead of `dateutil`
- Manual configuration parsing instead of `configparser` or `yaml`
- Custom logging instead of Python's `logging` module

**Example finding**:
```
❌ Reinventing the wheel - standard library exists
   src/cli.py:23-45 - Custom argument parsing with manual --flag handling

   Standard library: Python's argparse module

   Recommendation: Replace custom parsing with argparse:
   import argparse
   parser = argparse.ArgumentParser()
   parser.add_argument('--flag', help='description')
   args = parser.parse_args()

   Benefits: Automatic --help generation, type conversion, error handling
```

### Step 4: Review Imports and Dependencies

**Objective**: Check for redundant or conflicting dependencies.

**Method**:
```bash
# Check all imports in changed files
git diff main...HEAD | grep -E '^[+]import|^[+]from'

# Look for:
# - Multiple libraries for same purpose (requests + urllib3 + httpx)
# - Unused imports
# - Non-standard libraries when standard ones exist
```

**Common issues**:
- Importing entire module when only one function needed
- Multiple libraries imported for similar functionality
- Using third-party library when standard library sufficient

**Example finding**:
```
⚠️  Dependency consideration
   src/fetcher.py:5 - Added import: import httpx

   Note: Project already uses 'requests' library for HTTP

   Recommendation: Use consistent HTTP library across project:
   from requests import get, post

   Unless httpx provides specific required feature, prefer existing dependency
```

### Step 5: Verify Project Conventions and Patterns

**Objective**: Ensure code follows existing project patterns and architecture.

**Method**:
```bash
# Study similar existing code
git grep -l "similar_pattern"

# Compare structure:
# - Error handling approach
# - Function naming conventions
# - Module organization
# - Configuration management
```

**Check for**:
- Consistent error handling patterns
- Naming conventions (snake_case, camelCase, PascalCase)
- Module structure and organization
- Configuration approach (env vars, config files, CLI args)
- Logging patterns

**Example finding**:
```
⚠️  Inconsistent with project patterns
   src/new_module.py - Uses camelCase function names

   Project convention: snake_case for functions (see src/utils/, src/api/)

   Recommendation: Rename functions to match project style:
   - parseInput() → parse_input()
   - validateData() → validate_data()
```

## Workflow and Integration

### When to Use Review-Standard

Use the `/code-review` command:
- **Before creating a pull request**: Catch issues early
- **Before final merge to main**: Ensure quality standards
- **After milestone commits**: Validate incremental progress
- **On request**: When explicit review needed

### Integration with Document-Guideline

The `document-guideline` skill defines the standards; `review-standard` enforces them:

**document-guideline provides**:
- Documentation requirements (folder READMEs, source .md files, test docs)
- Content guidelines (what to document, how to structure)
- Workflow integration (design-first TDD, milestone flexibility)

**review-standard enforces**:
- Validates changes comply with documentation standards
- Checks for missing or incomplete documentation
- Leverages `scripts/lint-documentation.sh` for validation
- Provides specific remediation recommendations

### Integration with Milestone Workflow

**Milestone commits** (in-progress implementation):
- May bypass documentation linter with `--no-verify`
- Documentation-code inconsistency is acceptable
- Review should note progress toward completion

**Delivery commits** (final implementation):
- Must pass all linting without bypass
- Documentation must match implementation
- All tests must pass
- Review should confirm delivery readiness

**Example milestone review**:
```
✅ Milestone commit review
   Status: Milestone 2/3 (6/10 tests passing)

   Documentation: Complete and accurate for final state
   Code: 60% implemented, matches documented interfaces

   Notes:
   - Appropriate use of --no-verify for milestone commit
   - Documentation correctly describes intended final behavior
   - Partial implementation progressing as expected

   Recommendation: Continue implementation following documented design
```

### Command Invocation

The `/code-review` command invokes this skill automatically:

```bash
/code-review
```

The command handles:
1. Verifying current branch is not main
2. Getting changed files: `git diff --name-only main...HEAD`
3. Getting full diff: `git diff main...HEAD`
4. Invoking review-standard skill with context
5. Displaying formatted review report

## Review Report Format

Every review must produce a structured report with actionable feedback.

### Report Structure

```markdown
# Code Review Report

**Branch**: issue-42-feature-name
**Changed files**: 8 files (+450, -120 lines)
**Review date**: 2025-01-15

---

## Phase 1: Documentation Quality

### ✅ Passed
- All folders have README.md files
- Test files have inline documentation

### ❌ Issues Found

#### Missing source interface documentation
- `src/utils/parser.py` - No parser.md found

  **Recommendation**: Create parser.md documenting:
  - External Interface: parse_input(data) signature and behavior
  - Internal Helpers: _tokenize(), _validate_syntax() descriptions

### ⚠️  Warnings

#### Consider design documentation
- New authentication subsystem spans 5 files

  **Recommendation**: Consider docs/authentication.md to document architecture

---

## Phase 2: Code Quality & Reuse

### ✅ Passed
- No code duplication detected
- Imports follow project conventions

### ❌ Issues Found

#### Reinventing the wheel - local utility exists
- `src/api/handler.py:67` - Manual JSON validation

  **Existing utility**: src/utils/validators.py:validate_json()

  **Recommendation**: Replace with:
  ```python
  from src.utils.validators import validate_json
  result = validate_json(data)
  ```

### ⚠️  Warnings

#### Dependency consideration
- Added httpx library when requests already used

  **Recommendation**: Use consistent HTTP library (requests) unless httpx feature required

---

## Overall Assessment

**Status**: ⚠️  NEEDS CHANGES

**Summary**:
- 2 critical issues: missing documentation, code reuse opportunity
- 2 warnings: design doc consideration, dependency consistency

**Recommended actions before merge**:
1. Create parser.md documenting interfaces
2. Replace manual JSON validation with existing utility
3. Consider design doc for authentication subsystem
4. Evaluate httpx vs requests for HTTP client

**Merge readiness**: Not ready - address critical issues first
```

### Assessment Categories

**✅ APPROVED**:
- All documentation complete and accurate
- No code quality issues found
- All reuse opportunities identified and addressed
- Ready for merge

**⚠️  NEEDS CHANGES**:
- Minor documentation gaps
- Code reuse opportunities exist
- Non-critical improvements recommended
- Can merge after addressing issues

**❌ CRITICAL ISSUES**:
- Missing required documentation
- Significant code quality problems
- Major reuse opportunities ignored
- Security or correctness concerns
- Must address before merge

### Providing Actionable Feedback

Every issue must include:
1. **Specific location**: File path and line number
2. **Clear problem**: What's wrong and why it matters
3. **Concrete recommendation**: Exact steps to fix
4. **Example**: Code sample or specific implementation

**Bad feedback**:
```
❌ Documentation needs improvement
   Some files are missing docs
```

**Good feedback**:
```
❌ Missing interface documentation
   src/utils/parser.py - No parser.md found

   Recommendation: Create parser.md with:

   ## External Interface

   ### parse_input(data: str) -> dict
   Parses input string and returns structured data.

   **Parameters**: data (str) - Input string to parse
   **Returns**: dict - Parsed data structure
   **Raises**: ValueError - If data format invalid
```

## Summary

The review-standard skill provides a systematic approach to code review that:

1. **Validates documentation**: Ensures compliance with `document-guideline` standards
2. **Promotes code reuse**: Identifies existing utilities and prevents duplication
3. **Enforces quality**: Checks conventions, patterns, and best practices
4. **Provides actionable feedback**: Specific, implementable recommendations

Reviews are recommendations to help maintain quality - final merge decisions remain
with project maintainers.
