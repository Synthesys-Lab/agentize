# lint-documentation.sh

Pre-commit linter that enforces documentation completeness for folders, source code, and tests.

## External Interface

### Command-line Usage

```bash
# Run manually on all tracked files
./scripts/lint-documentation.sh

# Run as part of pre-commit hook (on staged files only)
git commit  # Automatically invokes the linter via pre-commit hook
```

### Exit Codes

- **0**: All documentation requirements satisfied, linting passed
- **1**: Missing documentation detected, linting failed

### Output

**Success output:**
```
Running documentation linter...
Checking folder documentation...
Checking source code documentation...
Checking test documentation...

✓ Documentation linting passed!
```

**Failure output:**
```
Running documentation linter...
Checking folder documentation...
Checking source code documentation...
Checking test documentation...

✗ Documentation linting failed!

Missing folder README.md files:
  - scripts/README.md
  - src/utils/README.md

Missing source code documentation files:
  - src/core.py.md -> src/core.md
  - src/utils/helper.cpp.md -> src/utils/helper.md

Missing test documentation:
  - tests/test_feature.md (or add inline documentation)

Please add the missing documentation files before committing.
For milestone commits, you can bypass this check with: git commit --no-verify
```

## Internal Helpers

### file_exists(path)
Check if a file exists at the given path.

**Parameters:**
- `path`: File path to check

**Returns:** 0 (true) if file exists, 1 (false) otherwise

### should_exclude_dir(dir)
Determine if a directory should be excluded from documentation checks.

**Exclusion criteria:**
- Hidden directories (starting with `.`)
- Common build/generated directories: `node_modules`, `build`, `dist`, `__pycache__`, `.git`, `.venv`, `venv`

**Parameters:**
- `dir`: Directory path to check

**Returns:** 0 (true) if should exclude, 1 (false) if should check

### should_exclude_file(file)
Determine if a file should be excluded from documentation checks.

**Exclusion criteria:**
- Files in hidden directories (paths starting with `.*`)
- Generated or temporary files: `*.pyc`, `*.pyo`, `*.o`, `*.so`, `*.dylib`, `*.a`

**Parameters:**
- `file`: File path to check

**Returns:** 0 (true) if should exclude, 1 (false) if should check

### has_inline_test_docs(test_file)
Check if a test file has inline documentation comments.

**Detection patterns (for shell scripts):**
- `# Test:` or `# Test N:` - Test case headers
- `# Purpose:` or `# Expected:` - Test purpose/expectation
- `# test_*()` - Function-level test comments

**Parameters:**
- `test_file`: Path to test file

**Returns:** 0 (true) if has inline docs, 1 (false) if no inline docs found

## Implementation Logic

### Check 1: Folder README.md Validation

1. Extract unique directories from staged/tracked files
2. For each directory:
   - Skip if excluded (hidden or generated directories)
   - Check if `README.md` exists
   - Add to errors if missing

### Check 2: Source Code .md File Validation

1. Iterate through staged/tracked files
2. For each file with source extension (`.py`, `.c`, `.cpp`, `.cxx`, `.cc`):
   - Skip if excluded
   - Derive expected `.md` file path (replace extension with `.md`)
   - Check if `.md` file exists
   - Add to errors if missing

### Check 3: Test Documentation Validation

1. Iterate through staged/tracked files
2. For each test file (in `tests/` or named `test_*.sh`):
   - Skip if excluded
   - For shell scripts: check for inline documentation first
   - If no inline docs, check for companion `.md` file
   - Add to errors if both missing

## Examples

### Example 1: Manual Run (All Files)

```bash
$ ./scripts/lint-documentation.sh
Running documentation linter...
Checking folder documentation...
Checking source code documentation...
Checking test documentation...

✓ Documentation linting passed!
```

### Example 2: Pre-commit Hook (Staged Files Only)

```bash
$ git add src/core.py
$ git commit -m "Add core functionality"

Running documentation linter...
Checking folder documentation...
Checking source code documentation...
Checking test documentation...

✗ Documentation linting failed!

Missing source code documentation files:
  - src/core.md

Please add the missing documentation files before committing.
For milestone commits, you can bypass this check with: git commit --no-verify
```

### Example 3: Bypass for Milestone

```bash
$ git commit --no-verify -m "[milestone] Work in progress"
[issue-42-feature abc1234] [milestone] Work in progress
 3 files changed, 150 insertions(+)
```

The `--no-verify` flag bypasses all pre-commit hooks, including the documentation linter.
