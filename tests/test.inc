# Common test infrastructure variables
# Include this in Makefiles that need test configuration

# Test temporary directory (project-local)
TEST_TMP_DIR := .tmp

# Build directory (for consistency across language templates)
BUILD_DIR := build

# Ensure test temp directory exists
$(TEST_TMP_DIR):
	@mkdir -p $(TEST_TMP_DIR)

# Common test cleanup patterns
.PHONY: clean-test
clean-test:
	@echo "Cleaning test artifacts..."
	@rm -rf $(TEST_TMP_DIR)
