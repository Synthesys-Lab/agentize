#!/usr/bin/env bash
# lol: AI-powered SDK CLI
# This file is sourced by setup.sh and provides all lol functionality
# Source-first implementation following the wt.sh pattern

# ============================================================================
# SECTION 1: HELPER FUNCTIONS
# ============================================================================

# Detect project language based on file structure
# Usage: lol_detect_lang <project_path>
# Returns: stdout: "python", "c", or "cxx"
#          exit code: 0 if detected, 1 if unable to detect
lol_detect_lang() {
    local project_path="$1"

    # Validate project path is provided
    if [ -z "$project_path" ]; then
        echo "Error: Project path is required" >&2
        return 1
    fi

    # Detect Python projects
    if [ -f "$project_path/requirements.txt" ] || \
       [ -f "$project_path/pyproject.toml" ] || \
       [ -n "$(find "$project_path" -maxdepth 2 -name '*.py' -print -quit 2>/dev/null)" ]; then
        echo "python"
        return 0
    fi

    # Detect C/C++ projects via CMakeLists.txt
    if [ -f "$project_path/CMakeLists.txt" ]; then
        # Check if CMakeLists.txt mentions CXX (C++) language
        if grep -q "project.*CXX" "$project_path/CMakeLists.txt" 2>/dev/null; then
            echo "cxx"
            return 0
        else
            echo "c"
            return 0
        fi
    fi

    # Unable to detect language
    echo "Warning: Could not detect project language" >&2
    return 1
}

# ============================================================================
# SECTION 2: COMPLETION HELPER
# ============================================================================

# Shell-agnostic completion helper
# Returns newline-delimited lists for shell completion systems
lol_complete() {
    local topic="$1"

    case "$topic" in
        commands)
            echo "apply"
            echo "init"
            echo "update"
            echo "upgrade"
            echo "project"
            ;;
        apply-flags)
            echo "--init"
            echo "--update"
            ;;
        init-flags)
            echo "--name"
            echo "--lang"
            echo "--path"
            echo "--source"
            echo "--metadata-only"
            ;;
        update-flags)
            echo "--path"
            ;;
        project-modes)
            echo "--create"
            echo "--associate"
            echo "--automation"
            ;;
        project-create-flags)
            echo "--org"
            echo "--title"
            ;;
        project-automation-flags)
            echo "--write"
            ;;
        lang-values)
            echo "c"
            echo "cxx"
            echo "python"
            ;;
        *)
            # Unknown topic, return empty
            return 0
            ;;
    esac
}

# ============================================================================
# SECTION 3: COMMAND IMPLEMENTATIONS (SUBSHELL FUNCTIONS)
# ============================================================================

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

# lol_cmd_upgrade: Upgrade agentize installation
# Runs in subshell to preserve set -e semantics
lol_cmd_upgrade() (
    set -e

    # Validate AGENTIZE_HOME is a valid git worktree
    if ! git -C "$AGENTIZE_HOME" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: AGENTIZE_HOME is not a valid git worktree."
        echo "  Current value: $AGENTIZE_HOME"
        exit 1
    fi

    # Check for uncommitted changes (dirty-tree guard)
    if [ -n "$(git -C "$AGENTIZE_HOME" status --porcelain)" ]; then
        echo "Warning: Uncommitted changes detected in AGENTIZE_HOME."
        echo ""
        echo "Please commit or stash your changes before upgrading:"
        echo "  git add ."
        echo "  git commit -m \"...\""
        echo "OR"
        echo "  git stash"
        exit 1
    fi

    # Resolve default branch from origin/HEAD, fallback to main
    local default_branch
    default_branch=$(git -C "$AGENTIZE_HOME" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -z "$default_branch" ]; then
        echo "Note: origin/HEAD not set, using 'main' as default branch"
        default_branch="main"
    fi

    echo "Upgrading agentize installation..."
    echo "  AGENTIZE_HOME: $AGENTIZE_HOME"
    echo "  Default branch: $default_branch"
    echo ""

    # Run git pull --rebase
    if git -C "$AGENTIZE_HOME" pull --rebase origin "$default_branch"; then
        echo ""
        echo "Upgrade successful!"
        echo ""
        echo "To apply changes, reload your shell:"
        echo "  exec \$SHELL                # Clean shell restart (recommended)"
        echo "OR"
        echo "  source \"\$AGENTIZE_HOME/setup.sh\"  # In-place reload"
        exit 0
    else
        echo ""
        echo "Error: git pull --rebase failed."
        echo ""
        echo "To resolve:"
        echo "1. Fix conflicts in the files listed above"
        echo "2. Stage resolved files: git add <file>"
        echo "3. Continue: git -C \$AGENTIZE_HOME rebase --continue"
        echo "OR abort: git -C \$AGENTIZE_HOME rebase --abort"
        echo ""
        echo "Then retry: lol upgrade"
        exit 1
    fi
)

# lol_cmd_version: Display version information
lol_cmd_version() {
    # Get installation commit from AGENTIZE_HOME
    local install_commit="Not a git repository"
    if git -C "$AGENTIZE_HOME" rev-parse HEAD >/dev/null 2>&1; then
        install_commit=$(git -C "$AGENTIZE_HOME" rev-parse HEAD)
    fi

    # Get project commit from .agentize.yaml
    local project_commit="Not set"
    local agentize_yaml=""

    # Search for .agentize.yaml in current directory and parents
    local search_path="$PWD"
    while [ "$search_path" != "/" ]; do
        if [ -f "$search_path/.agentize.yaml" ]; then
            agentize_yaml="$search_path/.agentize.yaml"
            break
        fi
        search_path="$(dirname "$search_path")"
    done

    # If found, extract agentize.commit field
    if [ -n "$agentize_yaml" ]; then
        # Parse YAML to extract agentize.commit value
        # Look for line matching "  commit: <hash>" under "agentize:" section
        local in_agentize_section=0
        while IFS= read -r line; do
            # Check if we're entering agentize section
            if echo "$line" | grep -q "^agentize:"; then
                in_agentize_section=1
                continue
            fi

            # Check if we've left the agentize section (new top-level key)
            if [ "$in_agentize_section" = "1" ] && echo "$line" | grep -q "^[a-z]"; then
                in_agentize_section=0
            fi

            # Extract commit if we're in agentize section
            if [ "$in_agentize_section" = "1" ]; then
                if echo "$line" | grep -q "^  commit:"; then
                    project_commit=$(echo "$line" | sed 's/^  commit: *//')
                    break
                fi
            fi
        done < "$agentize_yaml"
    fi

    # Display version information
    echo "Installation: $install_commit"
    echo "Last update:  $project_commit"
}

# lol_cmd_project: GitHub Projects v2 integration
# Runs in subshell to preserve set -e semantics
# Usage: lol_cmd_project <mode> [arg1] [arg2]
#   For create mode:    lol_cmd_project create [org] [title]
#   For associate mode: lol_cmd_project associate <org/id>
#   For automation mode: lol_cmd_project automation [write_path]
lol_cmd_project() (
    set -e

    # Positional arguments:
    #   $1 - mode: Operation mode - create, associate, automation (required)
    #   For create mode:
    #     $2 - org: Organization (optional, defaults to repo owner)
    #     $3 - title: Project title (optional, defaults to repo name)
    #   For associate mode:
    #     $2 - associate_arg: org/id argument (required, e.g., "Synthesys-Lab/3")
    #   For automation mode:
    #     $2 - write_path: Output path for workflow file (optional)

    local mode="$1"
    local arg1="$2"
    local arg2="$3"

    # Validate mode
    if [ -z "$mode" ]; then
        echo "Error: mode is required (argument 1)"
        echo "Usage: lol_cmd_project <mode> [arg1] [arg2]"
        exit 1
    fi

    # Find project root
    local PROJECT_ROOT
    PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "Error: Not in a git repository"
        echo ""
        echo "Please run this command from within a git repository."
        exit 1
    }

    # Metadata file path
    local METADATA_FILE="$PROJECT_ROOT/.agentize.yaml"

    # Helper: Preflight check
    _preflight_check() {
        # Skip preflight in fixture mode (tests use fixtures, not live gh auth)
        if [ "$AGENTIZE_GH_API" = "fixture" ]; then
            return 0
        fi

        if ! command -v gh &> /dev/null; then
            echo "Error: GitHub CLI (gh) is not installed"
            echo ""
            echo "Please install gh:"
            echo "  https://cli.github.com/manual/installation"
            exit 1
        fi

        if ! gh auth status &> /dev/null; then
            echo "Error: GitHub CLI is not authenticated"
            echo ""
            echo "Please authenticate gh:"
            echo "  gh auth login"
            exit 1
        fi
    }

    # Helper: Read value from .agentize.yaml
    _read_metadata() {
        local key="$1"
        if [ ! -f "$METADATA_FILE" ]; then
            return 1
        fi
        grep "^  $key:" "$METADATA_FILE" | sed "s/^  $key: *//" | head -1
    }

    # Helper: Update or add a field in .agentize.yaml under the project: section
    _update_metadata() {
        local key="$1"
        local value="$2"

        if [ ! -f "$METADATA_FILE" ]; then
            echo "Error: .agentize.yaml not found"
            echo ""
            echo "Please run 'lol init' or 'lol update' to create project metadata first."
            exit 1
        fi

        # Check if key exists in project section
        if grep -q "^  $key:" "$METADATA_FILE"; then
            # Update existing key (macOS compatible)
            sed -i.bak "s|^  $key:.*|  $key: $value|" "$METADATA_FILE"
            rm "$METADATA_FILE.bak"
        else
            # Add new key after project: line
            sed -i.bak "/^project:/a\\
  $key: $value
" "$METADATA_FILE"
            rm "$METADATA_FILE.bak"
        fi
    }

    # Helper: Create a new GitHub Projects v2 board
    _create_project() {
        local org="$arg1"
        local title="$arg2"

        # Default org to repository owner
        if [ -z "$org" ]; then
            org="$(gh repo view --json owner --jq '.owner.login' 2>/dev/null)" || {
                echo "Error: Unable to detect repository owner"
                echo ""
                echo "Please specify --org explicitly:"
                echo "  lol project --create --org <organization>"
                exit 1
            }
        fi

        # Default title to repository name
        if [ -z "$title" ]; then
            title="$(basename "$PROJECT_ROOT")"
        fi

        echo "Creating GitHub Projects v2 board:"
        echo "  Organization: $org"
        echo "  Title: $title"
        echo ""

        # Get organization ID for GraphQL mutation
        local owner_id
        owner_id="$(gh api graphql -f query='
            query($org: String!) {
                organization(login: $org) {
                    id
                }
            }' -f org="$org" --jq '.data.organization.id')" || {
            echo "Error: Unable to access organization '$org'"
            echo ""
            echo "Please ensure:"
            echo "  1. Organization exists"
            echo "  2. You have access to the organization"
            echo "  3. gh CLI has required permissions"
            exit 1
        }

        # Create project via GraphQL
        local result
        result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" create-project "$owner_id" "$title")" || {
            echo "Error: Failed to create project"
            exit 1
        }

        local project_number
        project_number="$(echo "$result" | jq -r '.data.createProjectV2.projectV2.number')"

        if [ -z "$project_number" ] || [ "$project_number" = "null" ]; then
            echo "Error: Failed to extract project number from GraphQL response"
            exit 1
        fi

        echo "Project created successfully: $org/$project_number"
        echo ""

        # Update metadata
        _update_metadata "org" "$org"
        _update_metadata "id" "$project_number"

        echo "Updated .agentize.yaml"
        echo ""
        echo "Project association complete."
        echo ""
        echo "Next steps:"
        echo "  1. Set up automation: lol project --automation"
        echo "  2. View your project: https://github.com/orgs/$org/projects/$project_number"
    }

    # Helper: Associate with an existing GitHub Projects v2 board
    _associate_project() {
        local associate_arg="$arg1"

        if [ -z "$associate_arg" ]; then
            echo "Error: --associate requires <org>/<id> argument"
            echo "Usage: lol project --associate <org>/<id>"
            exit 1
        fi

        # Parse org/id
        local org="${associate_arg%%/*}"
        local project_id="${associate_arg##*/}"

        if [ -z "$org" ] || [ -z "$project_id" ]; then
            echo "Error: Invalid format for --associate argument"
            echo "Expected: <org>/<id> (e.g., Synthesys-Lab/3)"
            echo "Got: $associate_arg"
            exit 1
        fi

        echo "Associating with GitHub Projects v2 board:"
        echo "  Organization: $org"
        echo "  Project ID: $project_id"
        echo ""

        # Verify project exists via GraphQL
        local result
        result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" lookup-project "$org" "$project_id")" || {
            echo "Error: Failed to look up project"
            exit 1
        }

        local project_title
        project_title="$(echo "$result" | jq -r '.data.organization.projectV2.title')"

        if [ -z "$project_title" ] || [ "$project_title" = "null" ]; then
            echo "Error: Project $org/$project_id not found or inaccessible"
            echo ""
            echo "Please ensure:"
            echo "  1. Project exists"
            echo "  2. You have access to the project"
            echo "  3. Project number is correct (not node_id)"
            exit 1
        fi

        echo "Found project: $project_title"
        echo ""

        # Update metadata
        _update_metadata "org" "$org"
        _update_metadata "id" "$project_id"

        echo "Updated .agentize.yaml"
        echo ""
        echo "Project association complete."
        echo ""
        echo "Next steps:"
        echo "  1. Set up automation: lol project --automation"
        echo "  2. View your project: https://github.com/orgs/$org/projects/$project_id"
    }

    # Helper: Generate automation workflow template
    _generate_automation() {
        local write_path="$arg1"

        # Read project metadata
        local org
        local project_id
        org="$(_read_metadata "org")"
        project_id="$(_read_metadata "id")"

        # Use defaults if not set
        if [ -z "$org" ]; then
            org="YOUR_ORG_HERE"
        fi
        if [ -z "$project_id" ]; then
            project_id="YOUR_PROJECT_ID_HERE"
        fi

        # Check Status field configuration
        if [ "$org" != "YOUR_ORG_HERE" ] && [ "$project_id" != "YOUR_PROJECT_ID_HERE" ]; then
            echo "Configuring Status field for project automation..."
            echo ""

            # Get project GraphQL ID
            local result
            result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" lookup-project "$org" "$project_id")" || {
                echo "Warning: Failed to look up project"
                echo ""
            }

            if [ -n "$result" ]; then
                local project_graphql_id
                project_graphql_id="$(echo "$result" | jq -r '.data.organization.projectV2.id')"

                if [ -n "$project_graphql_id" ] && [ "$project_graphql_id" != "null" ]; then
                    # List existing fields to verify Status field exists
                    local fields_result
                    fields_result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" list-fields "$project_graphql_id")" || {
                        echo "Warning: Failed to list fields"
                        echo ""
                    }

                    if [ -n "$fields_result" ]; then
                        # Check if Status field exists
                        local status_options
                        status_options="$(echo "$fields_result" | jq -r '.data.node.fields.nodes[] | select(.name == "Status") | .options[].name' | tr '\n' ', ' | sed 's/, $//')"

                        if [ -n "$status_options" ]; then
                            echo "Found Status field with options: $status_options"
                            echo ""
                            echo "The workflow will use:"
                            echo "  status-field: Status"
                            echo "  status-value: Proposed"
                        else
                            echo "Note: Status field not found or has no options"
                            echo "The workflow expects Status field options: Proposed, Plan Accepted, In Progress, Done"
                        fi
                    fi
                fi
            fi

            echo ""
        fi

        # Generate workflow content
        local workflow_content
        workflow_content="$(cat "$AGENTIZE_HOME/templates/github/project-auto-add.yml" | \
            sed "s/YOUR_ORG_HERE/$org/g" | \
            sed "s/YOUR_PROJECT_ID_HERE/$project_id/g")"

        if [ -n "$write_path" ]; then
            # Write to file
            local write_dir
            write_dir="$(dirname "$write_path")"
            mkdir -p "$write_dir"
            echo "$workflow_content" > "$write_path"
            echo "Automation workflow written to: $write_path"
            echo ""

            echo "Next steps:"
            echo ""
            echo "1. Create a GitHub Personal Access Token (PAT):"
            echo "   - Go to: https://github.com/settings/personal-access-tokens/new"
            echo "   - Token name: e.g., 'Add to Project Automation'"
            echo "   - Expiration: 90 days (recommended for security)"
            echo "   - Repository access: Select this repository"
            echo "   - Permissions:"
            echo "     - project: Read and write (required for adding items to projects)"
            echo "     - metadata: Read-only (automatically granted)"
            echo "   - Click 'Generate token' and copy it (you won't see it again)"
            echo ""
            echo "2. Add the PAT as a repository secret:"
            echo "   Using GitHub CLI (recommended):"
            echo "     gh secret set ADD_TO_PROJECT_PAT"
            echo "   Or via web interface:"
            echo "     Settings > Secrets and variables > Actions > New repository secret"
            echo "     Name: ADD_TO_PROJECT_PAT"
            echo ""
            echo "3. Commit and push the workflow file:"
            echo "   git add $write_path"
            echo "   git commit -m 'Add GitHub Projects automation workflow'"
            echo "   git push"
            echo ""
            echo "For detailed setup instructions and troubleshooting, see:"
            echo "  docs/workflows/github-projects-automation.md"
        else
            # Print to stdout
            echo "$workflow_content"
        fi
    }

    # Main execution
    case "$mode" in
        create)
            _preflight_check
            _create_project
            ;;
        associate)
            _preflight_check
            _associate_project
            ;;
        automation)
            _generate_automation
            ;;
        *)
            echo "Error: Invalid mode '$mode'"
            exit 1
            ;;
    esac
)

# ============================================================================
# SECTION 4: MAIN DISPATCHER
# ============================================================================

# Main lol function
lol() {
    # Handle completion helper before AGENTIZE_HOME validation
    # This allows completion to work even outside agentize context
    if [ "$1" = "--complete" ]; then
        lol_complete "$2"
        return 0
    fi

    # Check if AGENTIZE_HOME is set
    if [ -z "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME environment variable is not set"
        echo ""
        echo "Please set AGENTIZE_HOME to point to your agentize repository:"
        echo "  export AGENTIZE_HOME=\"/path/to/agentize\""
        echo "  source \"\$AGENTIZE_HOME/setup.sh\""
        return 1
    fi

    # Check if AGENTIZE_HOME is a valid directory
    if [ ! -d "$AGENTIZE_HOME" ]; then
        echo "Error: AGENTIZE_HOME does not point to a valid directory"
        echo "  Current value: $AGENTIZE_HOME"
        echo ""
        echo "Please set AGENTIZE_HOME to your agentize repository path:"
        echo "  export AGENTIZE_HOME=\"/path/to/agentize\""
        return 1
    fi

    # Check if Makefile exists
    if [ ! -f "$AGENTIZE_HOME/Makefile" ]; then
        echo "Error: Makefile not found at $AGENTIZE_HOME/Makefile"
        echo "  AGENTIZE_HOME may not point to a valid agentize repository"
        return 1
    fi

    # Handle --version flag as alias for version subcommand
    if [ "$1" = "--version" ]; then
        lol_cmd_version
        return $?
    fi

    # Parse subcommand
    local subcommand="$1"
    [ $# -gt 0 ] && shift

    case "$subcommand" in
        apply)
            _lol_parse_apply "$@"
            ;;
        init)
            _lol_parse_init "$@"
            ;;
        update)
            _lol_parse_update "$@"
            ;;
        upgrade)
            _lol_parse_upgrade "$@"
            ;;
        project)
            _lol_parse_project "$@"
            ;;
        version)
            lol_cmd_version
            ;;
        *)
            echo "lol: AI-powered SDK CLI"
            echo ""
            echo "Usage:"
            echo "  lol apply --init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
            echo "  lol apply --update [--path <path>]"
            echo "  lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
            echo "  lol update [--path <path>]"
            echo "  lol upgrade"
            echo "  lol --version"
            echo "  lol project --create [--org <org>] [--title <title>]"
            echo "  lol project --associate <org>/<id>"
            echo "  lol project --automation [--write <path>]"
            echo ""
            echo "Flags:"
            echo "  --version           Display version information"
            echo "  --init              Use init mode (apply only, requires --name and --lang)"
            echo "  --update            Use update mode (apply only)"
            echo "  --name <name>       Project name (required for init)"
            echo "  --lang <lang>       Programming language: c, cxx, python (required for init)"
            echo "  --path <path>       Project path (optional, defaults to current directory)"
            echo "  --source <path>     Source code path relative to project root (optional)"
            echo "  --metadata-only     Create only .agentize.yaml without SDK templates (optional, init only)"
            echo "  --create            Create new GitHub Projects v2 board (project)"
            echo "  --associate <org>/<id>  Associate existing project board (project)"
            echo "  --automation        Generate automation workflow template (project)"
            echo "  --write <path>      Write automation template to file (project)"
            echo "  --org <org>         GitHub organization (project --create)"
            echo "  --title <title>     Project title (project --create)"
            echo ""
            echo "Examples:"
            echo "  lol apply --init --name my-project --lang python --path /path/to/project"
            echo "  lol apply --update --path /path/to/project"
            echo "  lol init --name my-project --lang python --path /path/to/project"
            echo "  lol update                    # From project root or subdirectory"
            echo "  lol update --path /path/to/project"
            echo "  lol upgrade                   # Upgrade agentize installation"
            echo "  lol --version                 # Display version information"
            echo "  lol project --create --org Synthesys-Lab --title \"My Project\""
            echo "  lol project --associate Synthesys-Lab/3"
            echo "  lol project --automation --write .github/workflows/add-to-project.yml"
            return 1
            ;;
    esac
}

# ============================================================================
# SECTION 5: ARGUMENT PARSERS
# ============================================================================

# Parse apply command arguments and delegate to init or update
_lol_parse_apply() {
    local mode=""
    local remaining_args=()

    # First pass: detect mode and collect remaining arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --init)
                if [ -n "$mode" ]; then
                    echo "Error: Cannot use both --init and --update"
                    echo "Usage: lol apply --init|--update [flags...]"
                    return 1
                fi
                mode="init"
                shift
                ;;
            --update)
                if [ -n "$mode" ]; then
                    echo "Error: Cannot use both --init and --update"
                    echo "Usage: lol apply --init|--update [flags...]"
                    return 1
                fi
                mode="update"
                shift
                ;;
            *)
                # Collect remaining arguments for the delegated command
                remaining_args+=("$1")
                shift
                ;;
        esac
    done

    # Validate mode
    if [ -z "$mode" ]; then
        echo "Error: Must specify --init or --update"
        echo "Usage: lol apply --init|--update [flags...]"
        echo ""
        echo "Examples:"
        echo "  lol apply --init --name my-project --lang python"
        echo "  lol apply --update --path /path/to/project"
        return 1
    fi

    # Delegate to the appropriate command
    case "$mode" in
        init)
            _lol_parse_init "${remaining_args[@]}"
            ;;
        update)
            _lol_parse_update "${remaining_args[@]}"
            ;;
    esac
}

# Parse init command arguments and call lol_cmd_init
_lol_parse_init() {
    local name=""
    local lang=""
    local project_path=""
    local source=""
    local metadata_only="0"

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --name)
                name="$2"
                shift 2
                ;;
            --lang)
                lang="$2"
                shift 2
                ;;
            --path)
                project_path="$2"
                shift 2
                ;;
            --source)
                source="$2"
                shift 2
                ;;
            --metadata-only)
                metadata_only="1"
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage: lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
                return 1
                ;;
        esac
    done

    # Validate required flags
    if [ -z "$name" ]; then
        echo "Error: --name is required"
        echo "Usage: lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
        return 1
    fi

    if [ -z "$lang" ]; then
        echo "Error: --lang is required"
        echo "Usage: lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]"
        return 1
    fi

    # Use current directory if --path not provided
    if [ -z "$project_path" ]; then
        project_path="$PWD"
    fi

    # Convert to absolute path
    project_path="$(cd "$project_path" 2>/dev/null && pwd)" || {
        echo "Error: Invalid path '$project_path'"
        return 1
    }

    if [ "$metadata_only" = "1" ]; then
        echo "Initializing metadata only:"
    else
        echo "Initializing SDK:"
    fi
    echo "  Name: $name"
    echo "  Language: $lang"
    echo "  Path: $project_path"
    if [ -n "$source" ]; then
        echo "  Source: $source"
    fi
    if [ "$metadata_only" = "1" ]; then
        echo "  Mode: Metadata only (no templates)"
    fi
    echo ""

    # Call command with positional arguments
    lol_cmd_init "$project_path" "$name" "$lang" "$source" "$metadata_only"
}

# Parse update command arguments and call lol_cmd_update
_lol_parse_update() {
    local project_path=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --path)
                project_path="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage: lol update [--path <path>]"
                return 1
                ;;
        esac
    done

    # If no path provided, find nearest .claude/ directory
    if [ -z "$project_path" ]; then
        local search_path="$PWD"
        project_path=""
        while [ "$search_path" != "/" ]; do
            if [ -d "$search_path/.claude" ]; then
                project_path="$search_path"
                break
            fi
            search_path="$(dirname "$search_path")"
        done

        # If no .claude/ found, default to current directory with warning
        if [ -z "$project_path" ]; then
            project_path="$PWD"
            echo "Warning: No .claude/ directory found in current directory or parents"
            echo "  Defaulting to: $project_path"
            echo "  .claude/ will be created during update"
            echo ""
        fi
    else
        # Convert to absolute path
        project_path="$(cd "$project_path" 2>/dev/null && pwd)" || {
            echo "Error: Invalid path '$project_path'"
            return 1
        }

        # Allow missing .claude/ - it will be created during update
    fi

    echo "Updating SDK:"
    echo "  Path: $project_path"
    echo ""

    # Call command with positional arguments
    lol_cmd_update "$project_path"
}

# Parse upgrade command arguments and call lol_cmd_upgrade
_lol_parse_upgrade() {
    # Reject unexpected arguments
    if [ $# -gt 0 ]; then
        echo "Error: lol upgrade does not accept arguments"
        echo "Usage: lol upgrade"
        return 1
    fi

    lol_cmd_upgrade
}

# Parse project command arguments and call lol_cmd_project
_lol_parse_project() {
    local mode=""
    local org=""
    local title=""
    local associate_arg=""
    local automation="0"
    local write_path=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --create)
                if [ -n "$mode" ]; then
                    echo "Error: Cannot use --create with --associate or --automation"
                    echo "Usage: lol project --create [--org <org>] [--title <title>]"
                    return 1
                fi
                mode="create"
                shift
                ;;
            --associate)
                if [ -n "$mode" ]; then
                    echo "Error: Cannot use --associate with --create or --automation"
                    echo "Usage: lol project --associate <org>/<id>"
                    return 1
                fi
                mode="associate"
                associate_arg="$2"
                shift 2
                ;;
            --automation)
                if [ -n "$mode" ]; then
                    echo "Error: Cannot use --automation with --create or --associate"
                    echo "Usage: lol project --automation [--write <path>]"
                    return 1
                fi
                mode="automation"
                automation="1"
                shift
                ;;
            --org)
                org="$2"
                shift 2
                ;;
            --title)
                title="$2"
                shift 2
                ;;
            --write)
                write_path="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage:"
                echo "  lol project --create [--org <org>] [--title <title>]"
                echo "  lol project --associate <org>/<id>"
                echo "  lol project --automation [--write <path>]"
                return 1
                ;;
        esac
    done

    # Validate mode
    if [ -z "$mode" ]; then
        echo "Error: Must specify --create, --associate, or --automation"
        echo "Usage:"
        echo "  lol project --create [--org <org>] [--title <title>]"
        echo "  lol project --associate <org>/<id>"
        echo "  lol project --automation [--write <path>]"
        return 1
    fi

    # Call command with positional arguments
    # For create: lol_cmd_project create [org] [title]
    # For associate: lol_cmd_project associate <org/id>
    # For automation: lol_cmd_project automation [write_path]
    case "$mode" in
        create)
            lol_cmd_project "create" "$org" "$title"
            ;;
        associate)
            lol_cmd_project "associate" "$associate_arg"
            ;;
        automation)
            lol_cmd_project "automation" "$write_path"
            ;;
    esac
}
