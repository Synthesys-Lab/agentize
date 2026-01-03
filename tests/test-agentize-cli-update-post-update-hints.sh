#!/usr/bin/env bash
# Test: lol update prints conditional post-update setup hints

source "$(dirname "$0")/common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "lol update prints conditional post-update setup hints"

TEST_PROJECT=$(make_temp_dir "agentize-cli-update-post-update-hints")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

cd "$TEST_PROJECT"

# Test: No hints when Makefile/docs don't exist
UPDATE_OUTPUT=$(lol update 2>&1)
if echo "$UPDATE_OUTPUT" | grep -q "Next steps"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "'Next steps' should not appear when no Makefile/docs exist (Output: $UPDATE_OUTPUT)"
fi

# Test: Hints appear when Makefile with targets exists
cat > "$TEST_PROJECT/Makefile" <<'EOF'
test:
	echo "Running tests"

setup:
	echo "Running setup"
EOF

mkdir -p "$TEST_PROJECT/docs/architecture"
echo "# Architecture" > "$TEST_PROJECT/docs/architecture/architecture.md"

UPDATE_OUTPUT=$(lol update 2>&1)

# Verify hints appear
if ! echo "$UPDATE_OUTPUT" | grep -q "Next steps"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "'Next steps' hint header not found when Makefile exists (Output: $UPDATE_OUTPUT)"
fi

# Verify specific hints
if ! echo "$UPDATE_OUTPUT" | grep -q "make test"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "'make test' hint not found"
fi

if ! echo "$UPDATE_OUTPUT" | grep -q "make setup"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "'make setup' hint not found"
fi

if ! echo "$UPDATE_OUTPUT" | grep -q "docs/architecture/architecture.md"; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "architecture docs hint not found"
fi

cleanup_dir "$TEST_PROJECT"
test_pass "lol update prints conditional post-update setup hints"
