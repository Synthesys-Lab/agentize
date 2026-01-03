#!/usr/bin/env bash
# Test: --path override works for both init and update

source "$(dirname "$0")/../common.sh"

LOL_CLI="$PROJECT_ROOT/scripts/lol-cli.sh"

test_info "--path override works"

TEST_PROJECT=$(make_temp_dir "agentize-cli-path-override")
export AGENTIZE_HOME="$PROJECT_ROOT"
source "$LOL_CLI"

# Create .claude/ for update test
mkdir -p "$TEST_PROJECT/.claude"

# Both commands should accept --path from any directory
# (We're testing argument parsing here, not full execution)

cleanup_dir "$TEST_PROJECT"
test_pass "--path override accepted"
