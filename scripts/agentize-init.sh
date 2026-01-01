#!/bin/bash

set -e

# agentize-init.sh - Initialize new project with agentize templates
#
# Environment variables:
#   AGENTIZE_PROJECT_PATH  - Target project directory path
#   AGENTIZE_PROJECT_NAME  - Project name for template substitutions
#   AGENTIZE_PROJECT_LANG  - Project language (python, c, cxx)
#   AGENTIZE_SOURCE_PATH   - Source code path (optional, defaults to "src")
#
# Exit codes:
#   0 - Success
#   1 - Validation failed or initialization error

# Validate required environment variables
if [ -z "$AGENTIZE_PROJECT_PATH" ]; then
    echo "Error: AGENTIZE_PROJECT_PATH is not set"
    exit 1
fi

if [ -z "$AGENTIZE_PROJECT_NAME" ]; then
    echo "Error: AGENTIZE_PROJECT_NAME is not set"
    exit 1
fi

if [ -z "$AGENTIZE_PROJECT_LANG" ]; then
    echo "Error: AGENTIZE_PROJECT_LANG is not set"
    exit 1
fi

# Set default source path if not specified
SOURCE_PATH="${AGENTIZE_SOURCE_PATH:-src}"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Creating SDK for project: $AGENTIZE_PROJECT_NAME"
echo "Language: $AGENTIZE_PROJECT_LANG"
echo "Source path: $SOURCE_PATH"

# Check if metadata-only mode is enabled
if [ "${AGENTIZE_METADATA_ONLY:-0}" = "1" ]; then
    echo "Mode: Metadata only (no templates)"
    echo ""

    # In metadata-only mode, allow non-empty directories
    if [ ! -d "$AGENTIZE_PROJECT_PATH" ]; then
        echo "Creating directory '$AGENTIZE_PROJECT_PATH'..."
        mkdir -p "$AGENTIZE_PROJECT_PATH"
    fi
else
    echo "Initializing SDK structure..."

    # Standard mode: Check if directory exists and is not empty (excluding .git and .agentize.yaml)
    if [ -d "$AGENTIZE_PROJECT_PATH" ]; then
        # Count files excluding .git directory and .agentize.yaml file
        file_count=$(find "$AGENTIZE_PROJECT_PATH" -maxdepth 1 -mindepth 1 ! -name '.git' ! -name '.agentize.yaml' 2>/dev/null | wc -l)
        if [ "$file_count" -gt 0 ]; then
            echo "Error: Directory '$AGENTIZE_PROJECT_PATH' exists and is not empty."
            echo "Please use an empty directory or a non-existent path for init mode."
            exit 1
        fi
        echo "Directory exists and is empty, proceeding..."
    else
        echo "Creating directory '$AGENTIZE_PROJECT_PATH'..."
        mkdir -p "$AGENTIZE_PROJECT_PATH"
    fi
fi

# Skip template and .claude copying in metadata-only mode
if [ "${AGENTIZE_METADATA_ONLY:-0}" != "1" ]; then
    # Copy language template
    cp -r "$PROJECT_ROOT/templates/$AGENTIZE_PROJECT_LANG/"* "$AGENTIZE_PROJECT_PATH/"

    # Copy Claude Code configuration
    echo "Copying Claude Code configuration..."
    mkdir -p "$AGENTIZE_PROJECT_PATH/.claude"
    cp -r "$PROJECT_ROOT/.claude/"* "$AGENTIZE_PROJECT_PATH/.claude/"

    # Apply template substitutions to CLAUDE.md
    if [ -f "$PROJECT_ROOT/templates/claude/CLAUDE.md.template" ]; then
        sed -e "s/{{PROJECT_NAME}}/$AGENTIZE_PROJECT_NAME/g" \
            -e "s/{{PROJECT_LANG}}/$AGENTIZE_PROJECT_LANG/g" \
            "$PROJECT_ROOT/templates/claude/CLAUDE.md.template" > "$AGENTIZE_PROJECT_PATH/CLAUDE.md"
    fi

    # Copy documentation templates
    cp -r "$PROJECT_ROOT/templates/claude/docs" "$AGENTIZE_PROJECT_PATH/"
fi

# Create .agentize.yaml with project metadata (preserve if exists)
if [ -f "$AGENTIZE_PROJECT_PATH/.agentize.yaml" ]; then
    echo "Preserving existing .agentize.yaml..."
else
    echo "Creating .agentize.yaml with project metadata..."
    cat > "$AGENTIZE_PROJECT_PATH/.agentize.yaml" <<EOF
project:
  name: $AGENTIZE_PROJECT_NAME
  lang: $AGENTIZE_PROJECT_LANG
  source: $SOURCE_PATH
EOF
fi

# Optionally detect git default branch (only if .agentize.yaml was just created)
if [ ! -f "$AGENTIZE_PROJECT_PATH/.agentize.yaml.backup" ]; then
  if [ -d "$AGENTIZE_PROJECT_PATH/.git" ]; then
    if git -C "$AGENTIZE_PROJECT_PATH" show-ref --verify --quiet refs/heads/main; then
      echo "git:" >> "$AGENTIZE_PROJECT_PATH/.agentize.yaml"
      echo "  default_branch: main" >> "$AGENTIZE_PROJECT_PATH/.agentize.yaml"
    elif git -C "$AGENTIZE_PROJECT_PATH" show-ref --verify --quiet refs/heads/master; then
      echo "git:" >> "$AGENTIZE_PROJECT_PATH/.agentize.yaml"
      echo "  default_branch: master" >> "$AGENTIZE_PROJECT_PATH/.agentize.yaml"
    fi
  fi
fi

# Skip bootstrap in metadata-only mode
if [ "${AGENTIZE_METADATA_ONLY:-0}" != "1" ]; then
    # Run bootstrap script if it exists
    if [ -f "$AGENTIZE_PROJECT_PATH/bootstrap.sh" ]; then
        echo "Running bootstrap script..."
        chmod +x "$AGENTIZE_PROJECT_PATH/bootstrap.sh"
        (cd "$AGENTIZE_PROJECT_PATH" && \
         AGENTIZE_PROJECT_NAME="$AGENTIZE_PROJECT_NAME" \
         AGENTIZE_PROJECT_PATH="$AGENTIZE_PROJECT_PATH" \
         AGENTIZE_SOURCE_PATH="$SOURCE_PATH" \
         ./bootstrap.sh)
    fi
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

if [ "${AGENTIZE_METADATA_ONLY:-0}" = "1" ]; then
    echo "Metadata file created successfully at $AGENTIZE_PROJECT_PATH/.agentize.yaml"
else
    echo "SDK initialized successfully at $AGENTIZE_PROJECT_PATH"
fi
