#!/usr/bin/env bash
# lol_cmd_update: Update existing project with latest agentize configs

# lol_cmd_update: Update existing project with latest agentize configs
# Runs in subshell to preserve set -e semantics
# Usage: lol_cmd_update <project_path>
lol_cmd_update() (
    set -e

    # Positional arguments:
    #   $1 - project_path: Target project directory path (required)

    local project_path="$1"

    # Validate required arguments
    if [ -z "$project_path" ]; then
        echo "Error: project_path is required (argument 1)"
        exit 1
    fi

    # Get project root from AGENTIZE_HOME
    if [ -z "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME not set. Run 'make setup && source setup.sh' first." >&2
        exit 1
    fi
    local PROJECT_ROOT="$AGENTIZE_HOME"

    echo "Updating SDK structure..."

    # Validate project path exists
    if [ ! -d "$project_path" ]; then
        echo "Error: Project path '$project_path' does not exist."
        echo "Use AGENTIZE_MODE=init to create it."
        exit 1
    fi

    # Check if .claude directory exists, create if missing
    local CLAUDE_EXISTED=true
    if [ ! -d "$project_path/.claude" ]; then
        echo "  .claude/ directory not found, creating it..."
        mkdir -p "$project_path/.claude"
        CLAUDE_EXISTED=false
    fi

    # Backup existing .claude directory (only if it existed before)
    echo "Updating Claude Code configuration..."
    if [ "$CLAUDE_EXISTED" = true ]; then
        echo "  Backing up existing .claude/ to .claude.backup/"
        cp -r "$project_path/.claude" "$project_path/.claude.backup"
    fi

    # Update .claude contents with file-level copy to preserve user additions
    local file_count=0
    find "$PROJECT_ROOT/.claude" -type f -print0 | while IFS= read -r -d '' src_file; do
        local rel_path="${src_file#$PROJECT_ROOT/.claude/}"
        local dest_file="$project_path/.claude/$rel_path"
        mkdir -p "$(dirname "$dest_file")"
        cp "$src_file" "$dest_file"
        file_count=$((file_count + 1))
    done
    echo "  Updated .claude/ with file-level sync (preserves user-added files)"

    # Ensure docs/git-msg-tags.md exists
    if [ ! -f "$project_path/docs/git-msg-tags.md" ]; then
        echo "  Creating missing docs/git-msg-tags.md..."

        # Try to detect language (allow failure)
        set +e
        local DETECTED_LANG
        DETECTED_LANG=$(lol_detect_lang "$project_path" 2>/dev/null)
        local DETECT_EXIT_CODE=$?
        set -e

        if [ $DETECT_EXIT_CODE -eq 0 ]; then
            echo "    Detected language: $DETECTED_LANG"
            mkdir -p "$project_path/docs"

            if [ "$DETECTED_LANG" = "python" ]; then
                sed -e "/{{#if_python}}/d" \
                    -e "/{{\/if_python}}/d" \
                    -e "/{{#if_c_or_cxx}}/,/{{\/if_c_or_cxx}}/d" \
                    "$PROJECT_ROOT/templates/claude/docs/git-msg-tags.md.template" > "$project_path/docs/git-msg-tags.md"
            else
                sed -e "/{{#if_python}}/,/{{\/if_python}}/d" \
                    -e "/{{#if_c_or_cxx}}/d" \
                    -e "/{{\/if_c_or_cxx}}/d" \
                    "$PROJECT_ROOT/templates/claude/docs/git-msg-tags.md.template" > "$project_path/docs/git-msg-tags.md"
            fi
            echo "    Created docs/git-msg-tags.md"
        else
            echo "    Warning: Could not detect project language, using generic template"
            mkdir -p "$project_path/docs"
            # Use generic template with both sections removed
            sed -e "/{{#if_python}}/,/{{\/if_python}}/d" \
                -e "/{{#if_c_or_cxx}}/,/{{\/if_c_or_cxx}}/d" \
                "$PROJECT_ROOT/templates/claude/docs/git-msg-tags.md.template" > "$project_path/docs/git-msg-tags.md"
            echo "    Created docs/git-msg-tags.md (generic template)"
        fi
    else
        echo "  Existing CLAUDE.md and docs/git-msg-tags.md were preserved"
    fi

    # Create .agentize.yaml if missing
    if [ ! -f "$project_path/.agentize.yaml" ]; then
        echo "  Creating .agentize.yaml with best-effort metadata..."

        # Detect project name from directory basename
        local PROJECT_NAME
        PROJECT_NAME=$(basename "$project_path")

        # Try to detect language
        set +e
        local DETECTED_LANG
        DETECTED_LANG=$(lol_detect_lang "$project_path" 2>/dev/null)
        local DETECT_EXIT_CODE=$?
        set -e

        # Start building .agentize.yaml
        cat > "$project_path/.agentize.yaml" <<EOF
project:
  name: $PROJECT_NAME
EOF

        # Add language if detected
        if [ $DETECT_EXIT_CODE -eq 0 ] && [ -n "$DETECTED_LANG" ]; then
            echo "  lang: $DETECTED_LANG" >> "$project_path/.agentize.yaml"
        fi

        # Detect git default branch if git repository exists
        if [ -d "$project_path/.git" ]; then
            if git -C "$project_path" show-ref --verify --quiet refs/heads/main; then
                echo "git:" >> "$project_path/.agentize.yaml"
                echo "  default_branch: main" >> "$project_path/.agentize.yaml"
            elif git -C "$project_path" show-ref --verify --quiet refs/heads/master; then
                echo "git:" >> "$project_path/.agentize.yaml"
                echo "  default_branch: master" >> "$project_path/.agentize.yaml"
            fi
        fi

        echo "    Created .agentize.yaml"
    else
        echo "  Existing .agentize.yaml preserved"
    fi

    # Record agentize commit hash in .agentize.yaml
    if git -C "$AGENTIZE_HOME" rev-parse HEAD >/dev/null 2>&1; then
        local AGENTIZE_COMMIT
        AGENTIZE_COMMIT=$(git -C "$AGENTIZE_HOME" rev-parse HEAD)
        echo "  Recording agentize commit: $AGENTIZE_COMMIT"

        # Check if .agentize.yaml exists (it should by now)
        if [ -f "$project_path/.agentize.yaml" ]; then
            # Check if agentize section exists
            if grep -q "^agentize:" "$project_path/.agentize.yaml"; then
                # Update existing agentize.commit field
                # Use awk to update the commit line under agentize section
                awk -v commit="$AGENTIZE_COMMIT" '
                BEGIN { in_agentize = 0; commit_updated = 0 }
                /^agentize:/ { in_agentize = 1; print; next }
                /^[a-z]/ && in_agentize {
                    if (!commit_updated) {
                        print "  commit: " commit
                        commit_updated = 1
                    }
                    in_agentize = 0
                }
                in_agentize && /^  commit:/ {
                    print "  commit: " commit
                    commit_updated = 1
                    next
                }
                { print }
                END {
                    if (in_agentize && !commit_updated) {
                        print "  commit: " commit
                    }
                }
                ' "$project_path/.agentize.yaml" > "$project_path/.agentize.yaml.tmp"
                mv "$project_path/.agentize.yaml.tmp" "$project_path/.agentize.yaml"
            else
                # Add agentize section with commit field
                echo "agentize:" >> "$project_path/.agentize.yaml"
                echo "  commit: $AGENTIZE_COMMIT" >> "$project_path/.agentize.yaml"
            fi
        fi
    else
        echo "  Warning: AGENTIZE_HOME is not a git repository, skipping commit recording"
    fi

    # Copy scripts/pre-commit if missing (for older SDKs)
    if [ ! -f "$project_path/scripts/pre-commit" ] && [ -f "$PROJECT_ROOT/scripts/pre-commit" ]; then
        echo "  Copying missing scripts/pre-commit..."
        mkdir -p "$project_path/scripts"
        cp "$PROJECT_ROOT/scripts/pre-commit" "$project_path/scripts/pre-commit"
        chmod +x "$project_path/scripts/pre-commit"
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

    echo "SDK updated successfully at $project_path"

    # Print context-aware next steps hints
    local HINTS_PRINTED=false

    # Check for Makefile targets and available resources
    local HAS_TEST_TARGET=false
    local HAS_SETUP_TARGET=false
    if [ -f "$project_path/Makefile" ]; then
        HAS_TEST_TARGET=$(grep -q '^test:' "$project_path/Makefile" && echo "true" || echo "false")
        HAS_SETUP_TARGET=$(grep -q '^setup:' "$project_path/Makefile" && echo "true" || echo "false")
    fi

    local HAS_ARCH_DOC=false
    [ -f "$project_path/docs/architecture/architecture.md" ] && HAS_ARCH_DOC=true

    # Print hints header only if we have suggestions
    if [ "$HAS_TEST_TARGET" = "true" ] || [ "$HAS_SETUP_TARGET" = "true" ] || [ "$HAS_ARCH_DOC" = "true" ]; then
        echo ""
        echo "Next steps:"
        HINTS_PRINTED=true
    fi

    # Suggest available make targets
    if [ "$HAS_TEST_TARGET" = "true" ]; then
        echo "  - Run tests: make test"
    fi

    if [ "$HAS_SETUP_TARGET" = "true" ]; then
        echo "  - Setup hooks: make setup"
    fi

    # Point to architecture docs if available
    if [ "$HAS_ARCH_DOC" = "true" ]; then
        echo "  - See docs/architecture/architecture.md for details"
    fi
)
