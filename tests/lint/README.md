# Validation and Linting Tests

## Purpose

Static validation tests ensuring project structure integrity, linter correctness, and makefile consistency without executing full workflows.

## Contents

### Makefile Validation Tests (`test-makefile-*`)

Tests for makefile target correctness and parameter validation:

- `test-makefile-init-invalid-lang.sh` - Tests `make init` rejects invalid languages
- `test-makefile-init-without-lang.sh` - Tests `make init` behavior without language parameter
- `test-makefile-update-creates-git-tags.sh` - Tests `make update` creates git tag documentation
- `test-makefile-update-infers-lang.sh` - Tests `make update` auto-detects language
- `test-makefile-update-preserves-git-tags.sh` - Tests `make update` preserves existing git tags
- `test-makefile-update-without-lang.sh` - Tests `make update` behavior without explicit language
- `test-makefile-setup-zsh-completion.sh` - Tests `make setup` generates zsh completion scripts

### Shell Completion Tests (`test-*-zsh-completion-file.sh`)

Tests for shell completion script generation and correctness:

- `test-lol-zsh-completion-file.sh` - Validates `lol` zsh completion script structure
- `test-wt-zsh-completion-file.sh` - Validates `wt` zsh completion script structure

## Usage

Run all linting tests:
```bash
make test-lint
# or
bash tests/test-all.sh --category lint
```

Run a specific linting test:
```bash
bash tests/lint/test-makefile-update-creates-git-tags.sh
```

Run linting tests under multiple shells:
```bash
TEST_SHELLS="bash zsh" bash tests/lint/test-lol-zsh-completion-file.sh
```

## Test Characteristics

Linting tests are distinct from other test categories:

- **Fast execution**: No external dependencies, no workflows
- **Static validation**: Check files, structure, and patterns without execution
- **Precondition checks**: Validate assumptions before runtime
- **Build-time safety**: Catch configuration errors early

Linting tests use `tests/helpers-makefile-validation.sh` for shared makefile testing patterns.

## Test Strategy

Linting tests focus on:

1. **Parameter validation**: Ensure makefile targets reject invalid inputs
2. **File generation**: Verify generated files have correct structure
3. **Shell compatibility**: Validate completion scripts for bash/zsh

## Related Documentation

- [scripts/lint-documentation.sh](../../scripts/lint-documentation.sh) - Documentation linter implementation
- [tests/e2e/test-lint-documentation.sh](../e2e/test-lint-documentation.sh) - E2E linter integration test
- [tests/helpers-makefile-validation.sh](../helpers-makefile-validation.sh) - Makefile test helpers
- [tests/README.md](../README.md) - Test suite overview
