# Agentize Test Suite

## Purpose

This directory contains automated tests for the Agentize installation script (`scripts/install.sh`). Tests verify that installation works correctly across different modes (init, port) and language templates (Python, C++, C, Rust, multi-language).

### What We Test

- **Init mode**: Creates full project structure (`.claude/`, `Makefile`, `README.md`, `docs/`, `.gitignore`, `setup.sh`)
- **Port mode**: Creates only `.claude/` without modifying existing project files
- **Language templates**: Generates correct files for Python, C++, C, and Rust projects
- **Multi-language projects**: Combines templates and generates unified Makefile with delegating test targets

### What We Don't Test

- Whether generated projects build successfully (that's for the generated project's tests)
- SDK code quality (that's for code review)
- Performance (functional correctness only)

## Running Tests

### Run All Tests

```bash
make test
```

This executes `tests/run-all.sh`, which runs all test scripts and reports results.

**Exit codes**:
- `0`: All tests passed
- Non-zero: At least one test failed

### Run Individual Test

```bash
bash tests/test-init-mode.sh
bash tests/test-port-mode.sh
bash tests/test-languages.sh
```

Useful for debugging specific scenarios or verifying fixes.

### Clean Up Test Artifacts

```bash
make clean
```

Removes all temporary test directories in `/tmp/agentize-test-*`.

## Test Files

| File | Purpose | Key Scenarios |
|------|---------|---------------|
| `run-all.sh` | Main test runner | Executes all tests, reports summary, returns exit code |
| `test-init-mode.sh` | Init mode tests | Verifies full project creation: `.claude/`, `Makefile`, `README.md`, `docs/`, etc. |
| `test-port-mode.sh` | Port mode tests | Verifies only `.claude/` created, existing files preserved |
| `test-languages.sh` | Language template tests | Python, C++, C, Rust, multi-language project generation |

## Test Utilities

The `lib/` subdirectory contains shared testing infrastructure:

- **`lib/assertions.sh`**: Assertion functions for test verification
  - `assert_file_exists`, `assert_dir_exists`, `assert_file_contains`, etc.
- **`lib/test-utils.sh`**: Test setup/teardown utilities
  - `create_test_dir`, `cleanup_test_dir`, `run_agentize`

See [lib/README.md](lib/README.md) for complete API documentation.

## Adding New Tests

### Quick Guide

1. Create test file: `tests/test-feature.sh`
2. Add shebang and source libraries:
   ```bash
   #!/bin/bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/lib/assertions.sh"
   source "$SCRIPT_DIR/lib/test-utils.sh"
   ```
3. Implement test functions using assertions
4. Add test file to `run-all.sh` test list
5. Make executable: `chmod +x tests/test-feature.sh`
6. Verify: `make test`

### Template

See [docs/architecture/testing-infrastructure.md](../docs/architecture/testing-infrastructure.md#test-script-template) for a complete test script template.

## Test Isolation

Each test creates a unique temporary directory to ensure clean state:

**Pattern**: `/tmp/agentize-test-<test-name>-XXXXXX` (random suffix)

**Benefits**:
- No test pollution: Each test starts fresh
- Parallel-safe: No conflicts if tests run concurrently (future)
- Debugging-friendly: Can preserve temp dirs on failure

**Cleanup**:
- Automatic: `trap` ensures cleanup even on test failure
- Manual: `make clean` removes all test artifacts

## Test Scenarios

### Init Mode (`test-init-mode.sh`)

Verifies init mode creates complete project structure:

- [ ] `.claude/` directory with all subdirectories (agents, commands, rules, hooks)
- [ ] `docs/CLAUDE.md` template
- [ ] `Makefile` with build/test targets
- [ ] `README.md` project template
- [ ] `.gitignore` with common patterns
- [ ] `setup.sh` environment setup script
- [ ] File counts match expectations (13 agents, 8 commands, etc.)

### Port Mode (`test-port-mode.sh`)

Verifies port mode creates only `.claude/` without modifying existing files:

- [ ] `.claude/` directory created with same structure as init mode
- [ ] NO `Makefile` created (existing file preserved)
- [ ] NO `README.md` created (existing file preserved)
- [ ] NO `docs/` directory created
- [ ] NO `.gitignore` created
- [ ] NO `setup.sh` created

### Language Templates (`test-languages.sh`)

Verifies language-specific template generation:

**Python projects**:
- [ ] `pyproject.toml` with correct package name
- [ ] `lib/<package>/` directory structure
- [ ] `__init__.py` and `main.py` files
- [ ] `tests/test_main.py` test file
- [ ] Generated Makefile has `test-python` target

**C++ projects**:
- [ ] `CMakeLists.txt` with correct project name
- [ ] `include/<project>/` and `src/` directories
- [ ] Test infrastructure in `tests/`
- [ ] Generated Makefile has `test-cxx` target

**C projects**: (similar to C++)

**Rust projects**:
- [ ] `Cargo.toml` created via `cargo init`
- [ ] `src/main.rs` exists
- [ ] Generated Makefile has `test-rust` target
- [ ] Gracefully skips if `cargo` unavailable

**Multi-language projects**:
- [ ] Both Python and C++ structures created
- [ ] Generated Makefile aggregates test targets
- [ ] `make test` delegates to language-specific `test-python`, `test-cxx`

## Troubleshooting

### Tests Fail with "Permission denied"

**Cause**: Restrictive permissions on `/tmp` or disk full

**Solution**:
```bash
# Check /tmp permissions
ls -ld /tmp

# Standard /tmp permissions
sudo chmod 1777 /tmp

# Check disk space
df -h /tmp
```

### Temp Directories Not Cleaned Up

**Cause**: Test failed before cleanup or trap not registered

**Solution**:
```bash
# Manual cleanup
make clean

# Or remove specific test artifacts
rm -rf /tmp/agentize-test-*
```

### Test Passes Individually but Fails in Suite

**Cause**: Shared state or test order dependency

**Solution**:
- Verify each test uses `create_test_dir` with unique suffix
- Check for hardcoded paths
- Ensure no modification of source repository

### Debugging Test Failures

**Preserve temp directory**:
```bash
# Comment out cleanup in failing test
# cleanup_test_dir "$test_dir"

# Run test
bash tests/test-failing.sh

# Inspect results
ls -la /tmp/agentize-test-*
```

**Verbose execution**:
```bash
bash -x tests/test-init-mode.sh
```

## Subdirectories

- [lib/](lib/README.md) - Shared test utilities and assertion library

## Architecture Documentation

For detailed architecture, design decisions, and best practices, see:

[docs/architecture/testing-infrastructure.md](../docs/architecture/testing-infrastructure.md)
