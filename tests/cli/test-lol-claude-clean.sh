#!/usr/bin/env bash
# Test: lol claude-clean removes stale project entries from ~/.claude.json

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/src/cli/lol.sh"

test_info "lol claude-clean removes stale project entries"

export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Create temp directory for test
TMP_DIR=$(make_temp_dir "test-lol-claude-clean")
trap 'cleanup_dir "$TMP_DIR"' EXIT

# Create a valid directory and a path that doesn't exist
VALID_DIR="$TMP_DIR/valid-project"
STALE_PATH="$TMP_DIR/stale-project"
mkdir -p "$VALID_DIR"
# Note: STALE_PATH intentionally not created

# Create mock ~/.claude.json in temp location
MOCK_CLAUDE_JSON="$TMP_DIR/claude.json"
cat > "$MOCK_CLAUDE_JSON" << EOF
{
  "projects": {
    "$VALID_DIR": { "name": "valid" },
    "$STALE_PATH": { "name": "stale" }
  },
  "githubRepoPaths": {
    "owner/valid-repo": ["$VALID_DIR"],
    "owner/stale-repo": ["$STALE_PATH"],
    "owner/mixed-repo": ["$VALID_DIR", "$STALE_PATH"]
  }
}
EOF

# Override HOME for test
export HOME="$TMP_DIR"
mv "$MOCK_CLAUDE_JSON" "$TMP_DIR/.claude.json"

# Test 1: dry-run shows what would be removed
test_info "Test 1: dry-run shows stale entries"
dry_run_output=$(lol claude-clean --dry-run 2>&1)

echo "$dry_run_output" | grep -q "projects.*1" || test_fail "dry-run should report 1 stale project"
echo "$dry_run_output" | grep -q "$STALE_PATH" || test_fail "dry-run should list stale path"

# Verify file was NOT modified
after_dry_run=$(cat "$TMP_DIR/.claude.json")
echo "$after_dry_run" | jq -e ".projects[\"$STALE_PATH\"]" > /dev/null || test_fail "dry-run should not remove stale project"

# Test 2: apply removes stale entries
test_info "Test 2: apply removes stale entries"
apply_output=$(lol claude-clean 2>&1)

# Verify stale .projects key is removed
after_apply=$(cat "$TMP_DIR/.claude.json")
if echo "$after_apply" | jq -e ".projects[\"$STALE_PATH\"]" > /dev/null 2>&1; then
  test_fail "apply should remove stale project key"
fi

# Verify valid .projects key is preserved
echo "$after_apply" | jq -e ".projects[\"$VALID_DIR\"]" > /dev/null || test_fail "apply should preserve valid project key"

# Verify stale repo in .githubRepoPaths is removed (empty array case)
if echo "$after_apply" | jq -e ".githubRepoPaths[\"owner/stale-repo\"]" > /dev/null 2>&1; then
  test_fail "apply should remove repo key with all stale paths"
fi

# Verify valid repo is preserved
echo "$after_apply" | jq -e ".githubRepoPaths[\"owner/valid-repo\"]" > /dev/null || test_fail "apply should preserve repo with valid paths"

# Verify mixed repo has stale path removed but valid preserved
mixed_paths=$(echo "$after_apply" | jq -r '.githubRepoPaths["owner/mixed-repo"][]' 2>/dev/null)
echo "$mixed_paths" | grep -q "$VALID_DIR" || test_fail "mixed repo should preserve valid path"
if echo "$mixed_paths" | grep -q "$STALE_PATH"; then
  test_fail "mixed repo should remove stale path"
fi

# Test 3: no stale entries case
test_info "Test 3: no stale entries reports nothing to clean"
# Run again - should report no stale entries
no_stale_output=$(lol claude-clean --dry-run 2>&1)
echo "$no_stale_output" | grep -qi "no stale" || test_fail "should report no stale entries"

test_pass "lol claude-clean correctly handles stale project entries"
