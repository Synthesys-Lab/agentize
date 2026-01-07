# SDK Template Tests

## Purpose

Unit tests validating SDK template generation for different programming languages (C, C++, Python), ensuring correct project structure and build configuration.

## Contents

### C SDK Tests (`test-c-sdk*`)

Tests for C project template generation:

- `test-c-sdk.sh` - Tests basic C SDK generation with default configuration
- `test-c-sdk-default-src.sh` - Tests C SDK with default source directory layout
- `test-c-sdk-custom-lib.sh` - Tests C SDK with custom library configuration

### C++ SDK Tests (`test-cxx-sdk*`)

Tests for C++ project template generation:

- `test-cxx-sdk.sh` - Tests basic C++ SDK generation with default configuration
- `test-cxx-sdk-default-src.sh` - Tests C++ SDK with default source directory layout
- `test-cxx-sdk-custom-lib.sh` - Tests C++ SDK with custom library configuration

### Python SDK Tests

- `test-python-sdk.sh` - Tests Python SDK generation with package structure

## Usage

Run all SDK tests:
```bash
make test-sdk
# or
bash tests/test-all.sh --category sdk
```

Run tests for a specific language:
```bash
bash tests/sdk/test-c-sdk.sh
bash tests/sdk/test-python-sdk.sh
```

Run SDK tests under multiple shells:
```bash
TEST_SHELLS="bash zsh" bash tests/sdk/test-cxx-sdk.sh
```

## Test Coverage

SDK tests validate:

1. **Template instantiation**: `lol init` creates correct project structure
2. **File generation**: Required files exist (CMakeLists.txt, setup.py, etc.)
3. **Build configuration**: CMake/setup.py have correct language and library settings
4. **Directory structure**: Source, test, and build directories follow conventions
5. **Substitution correctness**: Project name/language variables replaced in templates

## Test Pattern

SDK tests typically:

1. Create temporary project directory
2. Run `lol init --name {project} --lang {language} --path {temp_dir}`
3. Verify generated files exist and contain expected content
4. Optionally test build system (e.g., `cmake -B build` succeeds)
5. Clean up temporary directory

## SDK Templates Location

SDK templates are located in:
- `templates/c/` - C project template
- `templates/cxx/` - C++ project template
- `templates/python/` - Python project template

Each template includes:
- `.claude/` directory structure
- Build configuration (CMakeLists.txt, setup.py)
- Sample source files with placeholders (`{{PROJECT_NAME}}`, `{{PROJECT_LANG}}`)

## Related Documentation

- [templates/](../../templates/) - SDK template source files
- [scripts/agentize-init.sh](../../scripts/agentize-init.sh) - Template instantiation logic
- [scripts/detect-lang.sh](../../scripts/detect-lang.sh) - Language detection for auto-inference
- [tests/cli/test-agentize-modes-init-*.sh](../cli/) - CLI-level init tests
- [tests/README.md](../README.md) - Test suite overview
