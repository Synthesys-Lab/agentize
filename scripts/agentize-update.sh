#!/bin/bash

set -e

# agentize-update.sh - Update existing project with latest agentize configs
#
# Environment variables:
#   AGENTIZE_PROJECT_PATH  - Target project directory path
#
# Exit codes:
#   0 - Success
#   1 - Validation failed or update error

# Validate required environment variables
if [ -z "$AGENTIZE_PROJECT_PATH" ]; then
    echo "Error: AGENTIZE_PROJECT_PATH is not set"
    exit 1
fi

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Updating SDK structure..."

# Validate project path exists
if [ ! -d "$AGENTIZE_PROJECT_PATH" ]; then
    echo "Error: Project path '$AGENTIZE_PROJECT_PATH' does not exist."
    echo "Use AGENTIZE_MODE=init to create it."
    exit 1
fi

# Validate .claude directory exists
if [ ! -d "$AGENTIZE_PROJECT_PATH/.claude" ]; then
    echo "Error: Directory '$AGENTIZE_PROJECT_PATH' is not a valid SDK structure."
    echo "Missing '.claude/' directory."
    echo "Please ensure this is an SDK created with 'make agentize' before using update mode."
    exit 1
fi

# Backup existing .claude directory
echo "Updating Claude Code configuration..."
echo "  Backing up existing .claude/ to .claude.backup/"
cp -r "$AGENTIZE_PROJECT_PATH/.claude" "$AGENTIZE_PROJECT_PATH/.claude.backup"

# Update .claude contents with file-level copy to preserve user additions
file_count=0
find "$PROJECT_ROOT/.claude" -type f -print0 | while IFS= read -r -d '' src_file; do
    rel_path="${src_file#$PROJECT_ROOT/.claude/}"
    dest_file="$AGENTIZE_PROJECT_PATH/.claude/$rel_path"
    mkdir -p "$(dirname "$dest_file")"
    cp "$src_file" "$dest_file"
    file_count=$((file_count + 1))
done
echo "  Updated .claude/ with file-level sync (preserves user-added files)"

# Ensure docs/git-msg-tags.md exists
if [ ! -f "$AGENTIZE_PROJECT_PATH/docs/git-msg-tags.md" ]; then
    echo "  Creating missing docs/git-msg-tags.md..."
    DETECTED_LANG=$("$PROJECT_ROOT/scripts/detect-lang.sh" "$AGENTIZE_PROJECT_PATH" 2>&1)

    if [ $? -eq 0 ]; then
        echo "    Detected language: $DETECTED_LANG"
        mkdir -p "$AGENTIZE_PROJECT_PATH/docs"

        if [ "$DETECTED_LANG" = "python" ]; then
            sed -e "/{{#if_python}}/d" \
                -e "/{{\/if_python}}/d" \
                -e "/{{#if_c_or_cxx}}/,/{{\/if_c_or_cxx}}/d" \
                "$PROJECT_ROOT/templates/claude/docs/git-msg-tags.md.template" > "$AGENTIZE_PROJECT_PATH/docs/git-msg-tags.md"
        else
            sed -e "/{{#if_python}}/,/{{\/if_python}}/d" \
                -e "/{{#if_c_or_cxx}}/d" \
                -e "/{{\/if_c_or_cxx}}/d" \
                "$PROJECT_ROOT/templates/claude/docs/git-msg-tags.md.template" > "$AGENTIZE_PROJECT_PATH/docs/git-msg-tags.md"
        fi
        echo "    Created docs/git-msg-tags.md"
    else
        echo "    $DETECTED_LANG"
    fi
else
    echo "  Existing CLAUDE.md and docs/git-msg-tags.md were preserved"
fi

echo "SDK updated successfully at $AGENTIZE_PROJECT_PATH"
