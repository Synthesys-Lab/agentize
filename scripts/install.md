# install.sh Refactoring Plan

## Overview

Refactor `generate_enhanced_makefile()` to use template-based approach instead of massive string concatenation in bash script.

## Current Implementation (Before)

The `generate_enhanced_makefile()` function:
- Builds 150+ lines of bash variables with escaped strings
- Uses `sed` to substitute placeholders in `claude/templates/project-Makefile.template`
- Variables include: `lang_flags`, `help_targets`, `env_setup`, `build_deps`, `build_commands`, `test_commands`, `lint_commands`, `clean_commands`, `language_targets`
- Hard to read, hard to maintain, hard to test

## New Implementation (After)

### 1. Template Files (Already Created)

Language-specific Makefile snippets in `templates/<lang>/Makefile.template`:
- `templates/python/Makefile.template` - Python build targets (build-python, test-python, clean-python, lint-python)
- `templates/c/Makefile.template` - C build targets (build-c, test-c, clean-c, lint-c)
- `templates/cxx/Makefile.template` - C++ build targets (build-cxx, test-cxx, clean-cxx, lint-cxx)
- `templates/rust/Makefile.template` - Rust build targets (build-rust, test-rust, clean-rust, lint-rust)

### 2. New `generate_enhanced_makefile()` Logic

```bash
generate_enhanced_makefile() {
    # Skip if Makefile exists or not in init mode

    # 1. Collect dependencies based on detected languages
    build_deps=""
    test_deps=""
    clean_deps=""
    lint_deps=""

    $HAS_PYTHON && build_deps="$build_deps build-python"
    $HAS_C && build_deps="$build_deps build-c"
    $HAS_CPP && build_deps="$build_deps build-cxx"
    $HAS_RUST && build_deps="$build_deps build-rust"

    # Similar for test_deps, clean_deps, lint_deps...

    # 2. Generate Makefile header with unified targets
    cat > "$MASTER_PROJ/Makefile" <<EOF
# ============================================================================
# ${PROJ_NAME} - Makefile
# ============================================================================

.PHONY: help
help:
	@echo "=============================="
	@echo "${PROJ_NAME}"
	@echo "=============================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help   - Show this help message"
	@echo "  build  - Build the project"
	@echo "  test   - Run all tests"
	@echo "  clean  - Clean build artifacts"
	@echo "  lint   - Run linters"
	@echo ""

.PHONY: build
build:${build_deps}

.PHONY: test
test:${test_deps}

.PHONY: clean
clean:${clean_deps}
	@rm -f setup.sh
	@echo "✓ Clean complete"

.PHONY: lint
lint:${lint_deps}

# ============================================================================
# Language-Specific Targets
# ============================================================================

EOF

    # 3. Append language-specific template files
    if $HAS_PYTHON; then
        cat "$AGENTIZE_ROOT/templates/python/Makefile.template" >> "$MASTER_PROJ/Makefile"
        echo "" >> "$MASTER_PROJ/Makefile"
    fi

    if $HAS_C; then
        cat "$AGENTIZE_ROOT/templates/c/Makefile.template" >> "$MASTER_PROJ/Makefile"
        echo "" >> "$MASTER_PROJ/Makefile"
    fi

    if $HAS_CPP; then
        cat "$AGENTIZE_ROOT/templates/cxx/Makefile.template" >> "$MASTER_PROJ/Makefile"
        echo "" >> "$MASTER_PROJ/Makefile"
    fi

    if $HAS_RUST; then
        cat "$AGENTIZE_ROOT/templates/rust/Makefile.template" >> "$MASTER_PROJ/Makefile"
        echo "" >> "$MASTER_PROJ/Makefile"
    fi

    # 4. Add default goal
    echo ".DEFAULT_GOAL := help" >> "$MASTER_PROJ/Makefile"
}
```

## Benefits

1. **Clarity**: Template files are plain Makefiles, easy to read and test
2. **Maintainability**: No more massive bash string escaping
3. **Composability**: Multi-language projects work naturally
   - `AGENTIZE_LANG=python,cpp` → `build: build-python build-cxx`
   - `AGENTIZE_LANG=python,c,rust` → `build: build-python build-c build-rust`
4. **Testability**: Each template can be tested independently
5. **Extensibility**: Adding new languages = just add new template file

## Example Output

For `AGENTIZE_LANG=python,cpp`, generated Makefile contains:

```makefile
# Header with project name
.PHONY: help
help:
    @echo "MyProject"
    ...

.PHONY: build
build: build-python build-cxx

.PHONY: test
test: test-python test-cxx

.PHONY: clean
clean: clean-python clean-cxx
    @rm -f setup.sh
    @echo "✓ Clean complete"

# Language-Specific Targets

# Python build targets
.PHONY: build-python
build-python:
    @echo "Building Python project..."
    @pip install -e .

.PHONY: test-python
test-python:
    @echo "Running Python tests..."
    @pytest tests/ -v

# C++ build targets
.PHONY: build-cxx
build-cxx:
    @echo "Building C++ project with CMake..."
    @cmake -B build -DCMAKE_BUILD_TYPE=Release
    @cmake --build build

.PHONY: test-cxx
test-cxx:
    @echo "Running C++ tests..."
    @cd build && ctest --output-on-failure

# ... (clean and lint targets for both languages)

.DEFAULT_GOAL := help
```

## Current Issues

1. **Bash 3.2 Compatibility**: The `<<<` here-string syntax causes issues on macOS default bash
   - Error: `syntax error near unexpected token 'then'` on line with `for lang in "${LANGS[@]}"; then`
   - Need to replace `IFS=',' read -ra LANGS <<< "$LANG"` with alternative approach
   - Options:
     - Use `echo "$LANG" | tr ',' '\n' | while read lang; do ...`
     - Use old-style here-document
     - Use simple string manipulation with `${LANG//,/ }`

2. **Testing**: Need to test multi-language combinations after fixing bash compatibility

## Files to Clean Up

After refactoring is complete, can delete:
- `claude/templates/project-Makefile.template` (no longer needed)

## Migration Path

1. Fix bash 3.2 compatibility issue in `detect_languages()`
2. Complete `generate_enhanced_makefile()` refactoring
3. Test with single and multi-language projects
4. Remove old `project-Makefile.template`
5. Update README.md reference from old template to new templates
