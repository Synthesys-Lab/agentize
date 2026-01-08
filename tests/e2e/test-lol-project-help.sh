#!/usr/bin/env bash
# Test: lol --help shows project subcommand usage information

source "$(dirname "$0")/../common.sh"

test_info "lol --help shows project subcommand usage information"

# Source the lol CLI library
source "$PROJECT_ROOT/src/cli/lol.sh"

# Capture help output (lol --help returns 1, so use || true to prevent set -e from exiting)
help_output=$(lol --help 2>&1) || true

# Check all three project subcommands
has_create=$(echo "$help_output" | grep -q "lol project --create" && echo "yes" || echo "no")
has_associate=$(echo "$help_output" | grep -q "lol project --associate" && echo "yes" || echo "no")
has_automation=$(echo "$help_output" | grep -q "lol project --automation" && echo "yes" || echo "no")

if [ "$has_create" = "yes" ] && [ "$has_associate" = "yes" ] && [ "$has_automation" = "yes" ]; then
    test_pass "Help text includes all project subcommands"
else
    test_fail "Help text missing project subcommands (create=$has_create, associate=$has_associate, automation=$has_automation)"
fi
