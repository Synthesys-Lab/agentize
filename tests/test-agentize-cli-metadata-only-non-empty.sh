#!/usr/bin/env bash
# Test: lol init --metadata-only creates .agentize.yaml in non-empty directory without .claude

source "$(dirname "$0")/common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "lol init --metadata-only in non-empty directory"

TEST_PROJECT=$(make_temp_dir "agentize-cli-metadata-only-non-empty")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Create a non-empty directory
echo "existing content" > "$TEST_PROJECT/existing-file.txt"

# Run init with --metadata-only
lol init --name test-project --lang python --path "$TEST_PROJECT" --metadata-only 2>/dev/null

# Verify .agentize.yaml was created
if [ ! -f "$TEST_PROJECT/.agentize.yaml" ]; then
  cleanup_dir "$TEST_PROJECT"
  test_fail ".agentize.yaml was not created by metadata-only init"
fi

# Verify .claude/ was NOT created
if [ -d "$TEST_PROJECT/.claude" ]; then
  cleanup_dir "$TEST_PROJECT"
  test_fail ".claude/ should not be created in metadata-only mode"
fi

# Verify existing file is still present
if [ ! -f "$TEST_PROJECT/existing-file.txt" ]; then
  cleanup_dir "$TEST_PROJECT"
  test_fail "Existing file was removed"
fi

cleanup_dir "$TEST_PROJECT"
test_pass "metadata-only mode creates .agentize.yaml in non-empty dir without .claude"
