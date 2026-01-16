#!/usr/bin/env bash
# Purpose: Shared gh CLI mock helpers for testing issue and PR operations
# Expected: Sourced by tests that need to mock gh CLI behavior

# Create gh CLI stub for issue view operations
# Sets up bin/gh in current directory with issue state mocking
# Usage: create_gh_stub
create_gh_stub() {
    mkdir -p bin
    cat > bin/gh <<'GHSTUB'
#!/usr/bin/env bash
# Stub gh command for testing
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  issue_no="$3"
  # Handle --json state flag for purge testing
  if [ "$4" = "--json" ] && [ "$5" = "state" ]; then
    # Check if --jq flag is present
    if [ "$6" = "--jq" ] && [ "$7" = ".state" ]; then
      # Return just the state value (simulating jq extraction)
      case "$issue_no" in
        42|50|51|55|100|200|210|300) echo "OPEN"; exit 0 ;;
        56|211|301|350) echo "CLOSED"; exit 0 ;;
        *) exit 1 ;;
      esac
    else
      # Return full JSON (for other use cases)
      case "$issue_no" in
        42|50|51|55|100|200|210|300) echo '{"state":"OPEN"}'; exit 0 ;;
        56|211|301|350) echo '{"state":"CLOSED"}'; exit 0 ;;
        *) exit 1 ;;
      esac
    fi
  else
    # Valid issue numbers return exit code 0, invalid ones return 1
    case "$issue_no" in
      42|50|51|55|56|100|200|210|211|300|301|350) exit 0 ;;
      *) exit 1 ;;
    esac
  fi
fi
GHSTUB
    chmod +x bin/gh
    export PATH="$PWD/bin:$PATH"
}

# Create gh mock for open-issue tests
# Sets up a gh stub that mocks issue create and edit operations
# Usage: setup_gh_mock_open_issue <mock_dir>
setup_gh_mock_open_issue() {
    local mock_dir="$1"

    cat > "$mock_dir/gh" <<'GHEOF'
#!/bin/bash
if [ "$1" = "issue" ] && [ "$2" = "create" ]; then
    # Extract title from arguments
    while [ $# -gt 0 ]; do
        if [ "$1" = "--title" ]; then
            echo "OPERATION: create" > "$GH_CAPTURE_FILE"
            echo "TITLE: $2" >> "$GH_CAPTURE_FILE"
            echo "{\"number\": 999, \"url\": \"https://github.com/test/repo/issues/999\"}"
            exit 0
        fi
        shift
    done
elif [ "$1" = "issue" ] && [ "$2" = "edit" ]; then
    # Extract issue number and title from arguments
    ISSUE_NUM="$3"
    while [ $# -gt 0 ]; do
        if [ "$1" = "--title" ]; then
            echo "OPERATION: edit" > "$GH_CAPTURE_FILE"
            echo "ISSUE: $ISSUE_NUM" >> "$GH_CAPTURE_FILE"
            echo "TITLE: $2" >> "$GH_CAPTURE_FILE"
            echo "{\"number\": $ISSUE_NUM, \"url\": \"https://github.com/test/repo/issues/$ISSUE_NUM\"}"
            exit 0
        fi
        shift
    done
fi
echo "{}"
GHEOF
    chmod +x "$mock_dir/gh"
}
