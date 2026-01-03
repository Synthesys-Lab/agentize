#!/usr/bin/env bash
# Shared helper for /open-issue tests

# Create gh mock for open-issue tests
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
