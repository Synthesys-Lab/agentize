#!/usr/bin/env bash
# Integration tests for SDK update mode

set -e

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_LIB="$SCRIPT_DIR/../lib"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test libraries
source "$TEST_LIB/assertions.sh"
source "$TEST_LIB/test-utils.sh"

# Test 1: Basic update flow
test_basic_update() {
    log_info "Test 1: Basic update flow"

    local test_dir=$(create_test_dir "basic-update")

    # Initialize project
    run_agentize "$test_dir" "TestUpdate" "init" || fail "Init failed"

    # Run update mode
    run_agentize "$test_dir" "TestUpdate" "update" || fail "Update failed"

    # Verify .claude/ still exists
    assert_dir_exists "$test_dir/.claude"

    # Verify backup was created
    local backup_count=$(ls -1d "$test_dir/.claude.backup."* 2>/dev/null | wc -l | tr -d ' ')
    if [ "$backup_count" -lt 1 ]; then
        fail "No backup directory created"
    fi

    cleanup_test_dir "$test_dir"
    increment_pass
}

# Test 2: SDK files are updated
test_sdk_files_updated() {
    log_info "Test 2: SDK files are updated"

    local test_dir=$(create_test_dir "sdk-files-updated")

    # Initialize project
    run_agentize "$test_dir" "TestSDK" "init" || fail "Init failed"

    # Modify an SDK-owned file
    local agent_file="$test_dir/.claude/agents/general-purpose.md"
    echo "MODIFIED BY TEST" >> "$agent_file"

    # Store modified content
    local modified_content=$(tail -1 "$agent_file")
    if [ "$modified_content" != "MODIFIED BY TEST" ]; then
        fail "Failed to modify test file"
    fi

    # Run update mode
    run_agentize "$test_dir" "TestSDK" "update" || fail "Update failed"

    # Verify file was restored to SDK version
    local updated_content=$(tail -1 "$agent_file")
    if [ "$updated_content" = "MODIFIED BY TEST" ]; then
        fail "SDK file was not updated (modification still present)"
    fi

    cleanup_test_dir "$test_dir"
    increment_pass
}

# Test 3: User files are preserved
test_user_files_preserved() {
    log_info "Test 3: User files are preserved"

    local test_dir=$(create_test_dir "user-files-preserved")

    # Initialize project
    run_agentize "$test_dir" "TestUser" "init" || fail "Init failed"

    # Modify user-owned file
    local custom_rules="$test_dir/.claude/rules/custom-project-rules.md"
    echo "MY CUSTOM RULE" >> "$custom_rules"

    # Modify another user-owned file
    local custom_workflows="$test_dir/.claude/rules/custom-workflows.md"
    echo "MY CUSTOM WORKFLOW" >> "$custom_workflows"

    # Run update mode
    run_agentize "$test_dir" "TestUser" "update" || fail "Update failed"

    # Verify custom-project-rules.md preserved
    assert_file_contains "$custom_rules" "MY CUSTOM RULE"

    # Verify custom-workflows.md preserved
    assert_file_contains "$custom_workflows" "MY CUSTOM WORKFLOW"

    cleanup_test_dir "$test_dir"
    increment_pass
}

# Test 4: Backup creation
test_backup_creation() {
    log_info "Test 4: Backup creation"

    local test_dir=$(create_test_dir "backup-creation")

    # Initialize project
    run_agentize "$test_dir" "TestBackup" "init" || fail "Init failed"

    # Create a marker file in .claude/
    echo "MARKER" > "$test_dir/.claude/marker.txt"

    # Run update mode
    run_agentize "$test_dir" "TestBackup" "update" || fail "Update failed"

    # Find backup directory
    local backup_dir=$(ls -1d "$test_dir/.claude.backup."* 2>/dev/null | head -1)
    if [ -z "$backup_dir" ]; then
        fail "Backup directory not found"
    fi

    # Verify backup contains marker file
    assert_file_exists "$backup_dir/marker.txt"
    assert_file_contains "$backup_dir/marker.txt" "MARKER"

    # Verify backup timestamp format (YYYYMMDD-HHMMSS)
    local backup_name=$(basename "$backup_dir")
    if [[ ! "$backup_name" =~ ^\.claude\.backup\.[0-9]{8}-[0-9]{6}(-[0-9]+)?$ ]]; then
        fail "Backup directory name format incorrect: $backup_name"
    fi

    cleanup_test_dir "$test_dir"
    increment_pass
}

# Test 5: Orphaned file reporting
test_orphaned_file_reporting() {
    log_info "Test 5: Orphaned file reporting"

    local test_dir=$(create_test_dir "orphaned-files")

    # Initialize project
    run_agentize "$test_dir" "TestOrphan" "init" || fail "Init failed"

    # Create a custom file that won't be in SDK
    local custom_agent="$test_dir/.claude/agents/my-custom-agent.md"
    echo "# My Custom Agent" > "$custom_agent"

    # Run update mode with skip for all prompts (capture output)
    local output=$(echo "s" | run_agentize "$test_dir" "TestOrphan" "update" 2>&1)

    # Verify custom file still exists
    assert_file_exists "$custom_agent"

    # Verify orphan warning was displayed
    if ! echo "$output" | grep -q "my-custom-agent\.md"; then
        fail "Expected orphaned file 'my-custom-agent.md' not found in output"
    fi

    cleanup_test_dir "$test_dir"
    increment_pass
}

# Test 6: Error when .claude/ doesn't exist
test_error_no_claude_dir() {
    log_info "Test 6: Error when .claude/ doesn't exist"

    local test_dir=$(create_test_dir "no-claude-dir")

    # Try to run update mode on empty directory (should fail)
    set +e
    run_agentize "$test_dir" "TestNoClaudeDir" "update" >/dev/null 2>&1
    local exit_code=$?
    set -e

    if [ "$exit_code" -eq 0 ]; then
        fail "Update mode should have failed without .claude/ directory"
    fi

    cleanup_test_dir "$test_dir"
    increment_pass
}

# Main test execution
main() {
    log_info "========================================"
    log_info "Running SDK Update Mode Integration Tests"
    log_info "========================================"
    echo ""

    test_basic_update
    test_sdk_files_updated
    test_user_files_preserved
    test_backup_creation
    test_orphaned_file_reporting
    test_error_no_claude_dir

    echo ""
    print_test_summary
}

main "$@"
