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

# Check if .claude directory exists, create if missing
CLAUDE_EXISTED=true
if [ ! -d "$AGENTIZE_PROJECT_PATH/.claude" ]; then
    echo "  .claude/ directory not found, creating it..."
    mkdir -p "$AGENTIZE_PROJECT_PATH/.claude"
    CLAUDE_EXISTED=false
fi

# Backup existing .claude directory (only if it existed before)
echo "Updating Claude Code configuration..."
if [ "$CLAUDE_EXISTED" = true ]; then
    echo "  Backing up existing .claude/ to .claude.backup/"
    cp -r "$AGENTIZE_PROJECT_PATH/.claude" "$AGENTIZE_PROJECT_PATH/.claude.backup"
fi

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

    # Try to detect language (allow failure)
    set +e
    DETECTED_LANG=$("$PROJECT_ROOT/scripts/detect-lang.sh" "$AGENTIZE_PROJECT_PATH" 2>/dev/null)
    DETECT_EXIT_CODE=$?
    set -e

    if [ $DETECT_EXIT_CODE -eq 0 ]; then
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
        echo "    Warning: Could not detect project language, using generic template"
        mkdir -p "$AGENTIZE_PROJECT_PATH/docs"
        # Use generic template with both sections removed
        sed -e "/{{#if_python}}/,/{{\/if_python}}/d" \
            -e "/{{#if_c_or_cxx}}/,/{{\/if_c_or_cxx}}/d" \
            "$PROJECT_ROOT/templates/claude/docs/git-msg-tags.md.template" > "$AGENTIZE_PROJECT_PATH/docs/git-msg-tags.md"
        echo "    Created docs/git-msg-tags.md (generic template)"
    fi
else
    echo "  Existing CLAUDE.md and docs/git-msg-tags.md were preserved"
fi

# Create .agentize.yaml if missing
if [ ! -f "$AGENTIZE_PROJECT_PATH/.agentize.yaml" ]; then
    echo "  Creating .agentize.yaml with best-effort metadata..."

    # Detect project name from directory basename
    PROJECT_NAME=$(basename "$AGENTIZE_PROJECT_PATH")

    # Try to detect language
    set +e
    DETECTED_LANG=$("$PROJECT_ROOT/scripts/detect-lang.sh" "$AGENTIZE_PROJECT_PATH" 2>/dev/null)
    DETECT_EXIT_CODE=$?
    set -e

    # Start building .agentize.yaml
    cat > "$AGENTIZE_PROJECT_PATH/.agentize.yaml" <<EOF
project:
  name: $PROJECT_NAME
EOF

    # Add language if detected
    if [ $DETECT_EXIT_CODE -eq 0 ] && [ -n "$DETECTED_LANG" ]; then
        echo "  lang: $DETECTED_LANG" >> "$AGENTIZE_PROJECT_PATH/.agentize.yaml"
    fi

    # Detect git default branch if git repository exists
    if [ -d "$AGENTIZE_PROJECT_PATH/.git" ]; then
        if git -C "$AGENTIZE_PROJECT_PATH" show-ref --verify --quiet refs/heads/main; then
            echo "git:" >> "$AGENTIZE_PROJECT_PATH/.agentize.yaml"
            echo "  default_branch: main" >> "$AGENTIZE_PROJECT_PATH/.agentize.yaml"
        elif git -C "$AGENTIZE_PROJECT_PATH" show-ref --verify --quiet refs/heads/master; then
            echo "git:" >> "$AGENTIZE_PROJECT_PATH/.agentize.yaml"
            echo "  default_branch: master" >> "$AGENTIZE_PROJECT_PATH/.agentize.yaml"
        fi
    fi

    echo "    Created .agentize.yaml"
else
    echo "  Existing .agentize.yaml preserved"
fi

# Copy scripts/pre-commit if missing (for older SDKs)
if [ ! -f "$AGENTIZE_PROJECT_PATH/scripts/pre-commit" ] && [ -f "$PROJECT_ROOT/scripts/pre-commit" ]; then
    echo "  Copying missing scripts/pre-commit..."
    mkdir -p "$AGENTIZE_PROJECT_PATH/scripts"
    cp "$PROJECT_ROOT/scripts/pre-commit" "$AGENTIZE_PROJECT_PATH/scripts/pre-commit"
    chmod +x "$AGENTIZE_PROJECT_PATH/scripts/pre-commit"
fi

# Install pre-commit hook if conditions are met
if [ -d "$AGENTIZE_PROJECT_PATH/.git" ] && [ -f "$AGENTIZE_PROJECT_PATH/scripts/pre-commit" ]; then
    # Check if pre_commit.enabled is set to false in metadata
    PRE_COMMIT_ENABLED=true
    if [ -f "$AGENTIZE_PROJECT_PATH/.agentize.yaml" ]; then
        if grep -q "pre_commit:" "$AGENTIZE_PROJECT_PATH/.agentize.yaml"; then
            if grep -A1 "pre_commit:" "$AGENTIZE_PROJECT_PATH/.agentize.yaml" | grep -q "enabled: false"; then
                PRE_COMMIT_ENABLED=false
            fi
        fi
    fi

    if [ "$PRE_COMMIT_ENABLED" = true ]; then
        # Check if hook already exists and is not ours
        if [ -f "$AGENTIZE_PROJECT_PATH/.git/hooks/pre-commit" ] && [ ! -L "$AGENTIZE_PROJECT_PATH/.git/hooks/pre-commit" ]; then
            echo "  Warning: Custom pre-commit hook detected, skipping installation"
        else
            echo "  Installing pre-commit hook..."
            mkdir -p "$AGENTIZE_PROJECT_PATH/.git/hooks"
            ln -sf ../../scripts/pre-commit "$AGENTIZE_PROJECT_PATH/.git/hooks/pre-commit"
            echo "  Pre-commit hook installed"
        fi
    else
        echo "  Skipping pre-commit hook installation (disabled in metadata)"
    fi
fi

echo "SDK updated successfully at $AGENTIZE_PROJECT_PATH"
