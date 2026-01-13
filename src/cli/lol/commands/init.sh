#!/usr/bin/env bash

# lol_cmd_init: Initialize new SDK project
# Runs in subshell to preserve set -e semantics
# Usage: lol_cmd_init <project_path> <project_name> <project_lang> [source_path] [metadata_only]
lol_cmd_init() (
    set -e

    # Positional arguments:
    #   $1 - project_path: Target project directory path (required)
    #   $2 - project_name: Project name for template substitutions (required)
    #   $3 - project_lang: Project language - python, c, cxx (required)
    #   $4 - source_path: Source code path (optional, defaults to "src")
    #   $5 - metadata_only: If "1", create only metadata file (optional, defaults to "0")

    local project_path="$1"
    local project_name="$2"
    local project_lang="$3"
    local source_path="${4:-src}"
    local metadata_only="${5:-0}"

    # Validate required arguments
    if [ -z "$project_path" ]; then
        echo "Error: project_path is required (argument 1)"
        exit 1
    fi

    if [ -z "$project_name" ]; then
        echo "Error: project_name is required (argument 2)"
        exit 1
    fi

    if [ -z "$project_lang" ]; then
        echo "Error: project_lang is required (argument 3)"
        exit 1
    fi

    # Get project root from AGENTIZE_HOME
    if [ -z "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME not set. Run 'make setup && source setup.sh' first." >&2
        exit 1
    fi
    local PROJECT_ROOT="$AGENTIZE_HOME"

    echo "Creating SDK for project: $project_name"
    echo "Language: $project_lang"
    echo "Source path: $source_path"

    # Check if metadata-only mode is enabled
    if [ "$metadata_only" = "1" ]; then
        echo "Mode: Metadata only (no templates)"
        echo ""

        # In metadata-only mode, allow non-empty directories
        if [ ! -d "$project_path" ]; then
            echo "Creating directory '$project_path'..."
            mkdir -p "$project_path"
        fi
    else
        echo "Initializing SDK structure..."

        # Standard mode: Check if directory exists and is not empty (excluding .git and .agentize.yaml)
        if [ -d "$project_path" ]; then
            # Count files excluding .git directory and .agentize.yaml file
            local file_count
            file_count=$(find "$project_path" -maxdepth 1 -mindepth 1 ! -name '.git' ! -name '.agentize.yaml' 2>/dev/null | wc -l)
            if [ "$file_count" -gt 0 ]; then
                echo "Error: Directory '$project_path' exists and is not empty."
                echo "Please use an empty directory or a non-existent path for init mode."
                exit 1
            fi
            echo "Directory exists and is empty, proceeding..."
        else
            echo "Creating directory '$project_path'..."
            mkdir -p "$project_path"
        fi
    fi

    # Skip template and .claude copying in metadata-only mode
    if [ "$metadata_only" != "1" ]; then
        # Copy language template
        cp -r "$PROJECT_ROOT/templates/$project_lang/"* "$project_path/"

        # Copy Claude Code configuration
        echo "Copying Claude Code configuration..."
        mkdir -p "$project_path/.claude"
        cp -r "$PROJECT_ROOT/.claude/"* "$project_path/.claude/"

        # Copy portable skills (commit-msg, open-issue) for SDK projects
        mkdir -p "$project_path/.claude/skills"
        for skill_name in commit-msg open-issue; do
            if [ -d "$PROJECT_ROOT/skills/$skill_name" ]; then
                cp -r "$PROJECT_ROOT/skills/$skill_name" "$project_path/.claude/skills/"
            fi
        done

        # Apply template substitutions to CLAUDE.md
        if [ -f "$PROJECT_ROOT/templates/claude/CLAUDE.md.template" ]; then
            sed -e "s/{{PROJECT_NAME}}/$project_name/g" \
                -e "s/{{PROJECT_LANG}}/$project_lang/g" \
                "$PROJECT_ROOT/templates/claude/CLAUDE.md.template" > "$project_path/CLAUDE.md"
        fi

        # Copy documentation templates
        cp -r "$PROJECT_ROOT/templates/claude/docs" "$project_path/"
    fi

    # Create .agentize.yaml with project metadata (preserve if exists)
    if [ -f "$project_path/.agentize.yaml" ]; then
        echo "Preserving existing .agentize.yaml..."
    else
        echo "Creating .agentize.yaml with project metadata..."
        {
            echo "project:"
            echo "  name: $project_name"
            echo "  lang: $project_lang"
            echo "  source: $source_path"
        } > "$project_path/.agentize.yaml"
    fi

    # Optionally detect git default branch (only if .agentize.yaml was just created)
    if [ ! -f "$project_path/.agentize.yaml.backup" ]; then
      if [ -d "$project_path/.git" ]; then
        if git -C "$project_path" show-ref --verify --quiet refs/heads/main; then
          echo "git:" >> "$project_path/.agentize.yaml"
          echo "  default_branch: main" >> "$project_path/.agentize.yaml"
        elif git -C "$project_path" show-ref --verify --quiet refs/heads/master; then
          echo "git:" >> "$project_path/.agentize.yaml"
          echo "  default_branch: master" >> "$project_path/.agentize.yaml"
        fi
      fi
    fi

    # Skip bootstrap in metadata-only mode
    if [ "$metadata_only" != "1" ]; then
        # Run bootstrap script if it exists
        if [ -f "$project_path/bootstrap.sh" ]; then
            echo "Running bootstrap script..."
            chmod +x "$project_path/bootstrap.sh"
            (cd "$project_path" && \
             AGENTIZE_PROJECT_NAME="$project_name" \
             AGENTIZE_PROJECT_PATH="$project_path" \
             AGENTIZE_SOURCE_PATH="$source_path" \
             ./bootstrap.sh)
        fi
    fi

    # Install pre-commit hook if conditions are met
    if [ -d "$project_path/.git" ] && [ -f "$project_path/scripts/pre-commit" ]; then
        # Check if pre_commit.enabled is set to false in metadata
        local PRE_COMMIT_ENABLED=true
        if [ -f "$project_path/.agentize.yaml" ]; then
            if grep -q "pre_commit:" "$project_path/.agentize.yaml"; then
                if grep -A1 "pre_commit:" "$project_path/.agentize.yaml" | grep -q "enabled: false"; then
                    PRE_COMMIT_ENABLED=false
                fi
            fi
        fi

        if [ "$PRE_COMMIT_ENABLED" = true ]; then
            # Check if hook already exists and is not ours
            if [ -f "$project_path/.git/hooks/pre-commit" ] && [ ! -L "$project_path/.git/hooks/pre-commit" ]; then
                echo "  Warning: Custom pre-commit hook detected, skipping installation"
            else
                echo "  Installing pre-commit hook..."
                mkdir -p "$project_path/.git/hooks"
                ln -sf ../../scripts/pre-commit "$project_path/.git/hooks/pre-commit"
                echo "  Pre-commit hook installed"
            fi
        else
            echo "  Skipping pre-commit hook installation (disabled in metadata)"
        fi
    fi

    if [ "$metadata_only" = "1" ]; then
        echo "Metadata file created successfully at $project_path/.agentize.yaml"
    else
        echo "SDK initialized successfully at $project_path"
    fi
)
