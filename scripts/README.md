# Scripts Directory

This directory contains utility scripts and git hooks for the project.

## Files

### Pre-commit Hook
- `pre-commit` - Git pre-commit hook script
  - Runs documentation linter before tests
  - Executes all test suites via `tests/test-all.sh`
  - Can be bypassed with `--no-verify` for milestone commits

### Documentation Linter
- `lint-documentation.sh` - Pre-commit documentation linter
  - Validates folder README.md existence
  - Validates source code .md file correspondence
  - Validates test documentation presence
  - Exit codes: 0 (pass), 1 (fail)

- `lint-documentation.md` - Documentation for the linter itself
  - External interface (usage, exit codes)
  - Internal helpers (check functions)
  - Examples of usage and output

## Usage

### Installing Pre-commit Hook

The pre-commit hook should be linked to `.git/hooks/pre-commit`:

```bash
# Link to git hooks (typically done during project setup)
ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
```

### Running Linter Manually

```bash
# Run on all tracked files
./scripts/lint-documentation.sh

# Check specific files (via git staging)
git add path/to/files
git commit  # Linter runs automatically
```

### Bypassing Hooks

For milestone commits where documentation exists but implementation is incomplete:

```bash
git commit --no-verify -m "[milestone] message"
```
