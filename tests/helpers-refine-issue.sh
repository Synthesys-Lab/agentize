#!/usr/bin/env bash
# Shared helper for /refine-issue tests

# Create gh mock for refine-issue tests
setup_gh_mock_refine() {
    local mock_dir="$1"
    local capture_dir="$2"

    cat > "$mock_dir/gh" <<GHEOF
#!/bin/bash
if [ "\$1" = "issue" ] && [ "\$2" = "view" ]; then
    # Return mock issue data
    cat <<'ISSUEEOF'
{
  "title": "[draft][plan][feat]: Add user authentication",
  "body": "## Description\\n\\nAdd user authentication with JWT tokens.\\n\\n## Proposed Solution\\n\\n### Implementation Steps\\n1. Add auth middleware\\n2. Create JWT utilities\\n3. Add login endpoint\\n\\nTotal LOC: ~150 (Medium)",
  "state": "OPEN"
}
ISSUEEOF
    exit 0
elif [ "\$1" = "issue" ] && [ "\$2" = "edit" ]; then
    # Capture the edit operation
    echo "EDIT: Issue \$3 updated" > "$capture_dir/gh-edit-capture.txt"
    # Capture body file content
    if [ "\$4" = "--body-file" ]; then
        cp "\$5" "$capture_dir/gh-edit-body-capture.txt"
    fi
    exit 0
fi
echo "{}"
GHEOF
    chmod +x "$mock_dir/gh"
}
