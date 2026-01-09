#!/usr/bin/env bash
# Test: lol serve uses correct gh GraphQL variable types (-f for strings, -F for ints)

source "$(dirname "$0")/../common.sh"

test_info "lol serve uses correct gh GraphQL variable types"

TMP_DIR=$(make_temp_dir "test-lol-serve-graphql")
ARGS_FILE="$TMP_DIR/gh_args.txt"

# Create a stubbed gh command that captures args
mkdir -p "$TMP_DIR/bin"
cat > "$TMP_DIR/bin/gh" << 'STUB'
#!/bin/bash
# Capture all arguments to a file
echo "$@" >> "$ARGS_FILE"

# Return minimal valid JSON for query_project_items
cat << 'JSON'
{"data":{"organization":{"projectV2":{"items":{"nodes":[]}}}}}
JSON
STUB
chmod +x "$TMP_DIR/bin/gh"

# Export ARGS_FILE for the stub
export ARGS_FILE

# Override PATH to use our stub
export PATH="$TMP_DIR/bin:$PATH"

# Create minimal .agentize.yaml
cat > "$TMP_DIR/.agentize.yaml" << 'YAML'
project:
  org: TestOrg
  id: 42
YAML

# Run query_project_items via Python
cd "$TMP_DIR"
python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/python')
from agentize.server.__main__ import query_project_items
query_project_items('TestOrg', 42)
"

# Check that gh was called with correct args
if [ ! -f "$ARGS_FILE" ]; then
  test_fail "gh command was not called"
fi

CAPTURED=$(cat "$ARGS_FILE")

# Test 1: Check for -f org=TestOrg (string variable)
if ! echo "$CAPTURED" | grep -q "\-f org=TestOrg"; then
  test_fail "Missing -f org=TestOrg in gh args: $CAPTURED"
fi

# Test 2: Check for -F projectNumber=42 (integer variable)
if ! echo "$CAPTURED" | grep -q "\-F projectNumber=42"; then
  test_fail "Missing -F projectNumber=42 in gh args: $CAPTURED"
fi

# Test 3: Should NOT have -f variables= (old broken pattern)
if echo "$CAPTURED" | grep -q "\-f variables="; then
  test_fail "Found old -f variables= pattern (should use typed args): $CAPTURED"
fi

# Cleanup
cleanup_dir "$TMP_DIR"

test_pass "lol serve uses correct gh GraphQL variable types"
