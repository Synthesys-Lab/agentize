#!/bin/bash
set -e

# ============================================================================
# Agentize SDK Installation Script
# ============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
MASTER_PROJ="${1:?Error: Missing AGENTIZE_MASTER_PROJ argument}"
PROJ_NAME="${2:-MyProject}"
MODE="${3:-init}"
LANG="${4:-}"
IMPL_DIR="${5:-src}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTIZE_ROOT="$(dirname "$SCRIPT_DIR")"

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

log_error() {
    echo -e "${RED}✗${NC}  $1"
}

# Transform project name to snake_case for Python/Rust packages
transform_project_name() {
    echo "$PROJ_NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_' | sed 's/[^a-z0-9_]//g'
}

# Transform project name to alphanumeric for CMake
transform_project_name_cmake() {
    echo "$PROJ_NAME" | sed 's/[^a-zA-Z0-9_]//g'
}

# Detect languages and set flags
detect_languages() {
    HAS_PYTHON=false
    HAS_C=false
    HAS_CPP=false
    HAS_RUST=false

    # Default to C++ if no language specified
    if [ -z "$LANG" ]; then
        HAS_CPP=true
        log_info "No language specified, defaulting to C++"
        return
    fi

    # Parse comma-separated language list (bash 3.2 compatible)
    OLDIFS="$IFS"
    IFS=','
    for lang in $LANG; do
        IFS="$OLDIFS"
        # Trim whitespace
        lang=$(echo "$lang" | tr -d ' ')
        case "$lang" in
            python|py)
                HAS_PYTHON=true
                ;;
            c)
                HAS_C=true
                ;;
            cpp|cxx|c++)
                HAS_CPP=true
                ;;
            rust|rs)
                HAS_RUST=true
                ;;
            *)
                log_warning "Unknown language: $lang (ignoring)"
                ;;
        esac
    done

    # Log detected languages
    local detected=""
    $HAS_PYTHON && detected="${detected}Python "
    $HAS_C && detected="${detected}C "
    $HAS_CPP && detected="${detected}C++ "
    $HAS_RUST && detected="${detected}Rust "

    if [ -n "$detected" ]; then
        log_info "Detected languages: $detected"
    fi
}

# ============================================================================
# Validation
# ============================================================================

validate_target_project() {
    log_info "Validating target project: $MASTER_PROJ"

    if [ ! -d "$MASTER_PROJ" ]; then
        log_error "Target directory does not exist: $MASTER_PROJ"
        exit 1
    fi

    # Check if .claude already exists
    if [ -d "$MASTER_PROJ/.claude" ]; then
        log_warning ".claude directory already exists at $MASTER_PROJ/.claude"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled by user"
            exit 0
        fi
        rm -rf "$MASTER_PROJ/.claude"
    fi

    # Validate mode
    if [ "$MODE" != "init" ] && [ "$MODE" != "port" ] && [ "$MODE" != "update" ]; then
        log_error "Invalid mode: $MODE (must be 'init', 'port', or 'update')"
        exit 1
    fi

    log_success "Validation complete"
}

# Validate target for update mode
validate_update_target() {
    if [ ! -d "$MASTER_PROJ/.claude" ]; then
        log_error "No .claude/ directory found in $MASTER_PROJ"
        log_error "Use 'init' or 'port' mode to create .claude/ first"
        exit 1
    fi

    log_success "Found existing .claude/ directory for update"
}

# Create timestamped backup of .claude/ directory
create_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$MASTER_PROJ/.claude.backup.$timestamp"

    # Handle timestamp collision (unlikely but possible)
    while [ -d "$backup_dir" ]; do
        backup_dir="${backup_dir}-${RANDOM}"
    done

    # Copy entire .claude/ directory to backup
    if ! cp -r "$MASTER_PROJ/.claude" "$backup_dir"; then
        log_error "Failed to create backup at $backup_dir"
        exit 1
    fi

    log_success "Backup created: $backup_dir"
    # Store backup path for use in summary
    BACKUP_DIR="$backup_dir"
}

# ============================================================================
# Directory Structure Creation
# ============================================================================

create_directory_structure() {
    log_info "Creating .claude/ directory structure..."

    mkdir -p "$MASTER_PROJ/.claude"
    mkdir -p "$MASTER_PROJ/.claude/agents"
    mkdir -p "$MASTER_PROJ/.claude/commands"
    mkdir -p "$MASTER_PROJ/.claude/rules"
    mkdir -p "$MASTER_PROJ/.claude/skills"
    mkdir -p "$MASTER_PROJ/.claude/hooks"

    log_success "Directory structure created"
}

# ============================================================================
# Component Copying
# ============================================================================

copy_components() {
    log_info "Copying AI workflow components..."

    # Copy agents
    if [ -d "$AGENTIZE_ROOT/claude/agents" ]; then
        cp "$AGENTIZE_ROOT/claude/agents"/*.md "$MASTER_PROJ/.claude/agents/" 2>/dev/null || true
        local agent_count=$(ls -1 "$AGENTIZE_ROOT/claude/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')
        log_success "Copied $agent_count agents"
    fi

    # Copy commands
    if [ -d "$AGENTIZE_ROOT/claude/commands" ]; then
        cp "$AGENTIZE_ROOT/claude/commands"/*.md "$MASTER_PROJ/.claude/commands/" 2>/dev/null || true
        local cmd_count=$(ls -1 "$AGENTIZE_ROOT/claude/commands"/*.md 2>/dev/null | wc -l | tr -d ' ')
        log_success "Copied $cmd_count commands"
    fi

    # Copy rules
    if [ -d "$AGENTIZE_ROOT/claude/rules" ]; then
        cp "$AGENTIZE_ROOT/claude/rules"/*.md "$MASTER_PROJ/.claude/rules/" 2>/dev/null || true
        local rule_count=$(ls -1 "$AGENTIZE_ROOT/claude/rules"/*.md 2>/dev/null | wc -l | tr -d ' ')
        log_success "Copied $rule_count rules"
    fi

    # Copy skills
    if [ -d "$AGENTIZE_ROOT/claude/skills" ]; then
        cp "$AGENTIZE_ROOT/claude/skills"/*.md "$MASTER_PROJ/.claude/skills/" 2>/dev/null || true
        local skill_count=$(ls -1 "$AGENTIZE_ROOT/claude/skills"/*.md 2>/dev/null | wc -l | tr -d ' ')
        log_success "Copied $skill_count skills"
    fi

    # Copy hooks
    if [ -d "$AGENTIZE_ROOT/claude/hooks" ]; then
        cp -r "$AGENTIZE_ROOT/claude/hooks"/* "$MASTER_PROJ/.claude/hooks/" 2>/dev/null || true
        log_success "Copied hooks"
    fi

    # Copy README
    if [ -f "$AGENTIZE_ROOT/claude/README.md" ]; then
        cp "$AGENTIZE_ROOT/claude/README.md" "$MASTER_PROJ/.claude/README.md"
        log_success "Copied README.md"
    fi
}

# ============================================================================
# Update Mode Functions
# ============================================================================

# Update SDK-owned directories (replace completely)
update_sdk_directories() {
    log_info "Updating SDK-owned directories..."

    local dirs=("agents" "commands" "skills" "hooks")

    for dir in "${dirs[@]}"; do
        # Remove old directory and replace with SDK version
        rm -rf "$MASTER_PROJ/.claude/$dir"
        cp -r "$AGENTIZE_ROOT/claude/$dir" "$MASTER_PROJ/.claude/$dir"
        log_success "Updated $dir/"
    done

    # Update README.md
    cp "$AGENTIZE_ROOT/claude/README.md" "$MASTER_PROJ/.claude/README.md"
    log_success "Updated README.md"
}

# Update SDK-owned rules selectively (preserve user-owned files)
update_sdk_rules() {
    log_info "Updating SDK-owned rules..."

    local sdk_rules=(
        "language.md"
        "git-commit-format.md"
        "issue-pr-format.md"
        "milestone-guide.md"
        "file-movement-protocol.md"
        "github-comment-attribution.md"
        "project-board-integration.md"
        "summary-preferences.md"
        "documentation-guidelines.md"
    )

    for rule in "${sdk_rules[@]}"; do
        cp "$AGENTIZE_ROOT/claude/rules/$rule" "$MASTER_PROJ/.claude/rules/$rule"
    done

    log_success "Updated rules/"
    log_info "Preserved: custom-project-rules.md, custom-workflows.md"
}

# Report orphaned files (present in target but not in SDK)
report_orphaned_files() {
    log_info "Checking for orphaned files..."

    local orphans=()

    while IFS= read -r file; do
        local rel_path="${file#$MASTER_PROJ/.claude/}"
        local sdk_path="$AGENTIZE_ROOT/claude/$rel_path"

        # Skip user-owned files (these are expected to not be in SDK)
        [[ "$rel_path" == "rules/custom-project-rules.md" ]] && continue
        [[ "$rel_path" == "rules/custom-workflows.md" ]] && continue

        # Skip backup directories
        [[ "$rel_path" =~ ^\.claude\.backup ]] && continue

        # Check if file exists in SDK
        if [ ! -f "$sdk_path" ]; then
            orphans+=("$rel_path")
        fi
    done < <(find "$MASTER_PROJ/.claude" -type f)

    if [ ${#orphans[@]} -gt 0 ]; then
        log_warning "Orphaned files (not in SDK):"
        for orphan in "${orphans[@]}"; do
            echo "  - $orphan"
        done
        log_info "These files were NOT deleted. Remove manually if not needed."
    else
        log_success "No orphaned files found"
    fi
}

# Handle templated files with interactive prompts
handle_templated_files() {
    log_info "Checking templated files for changes..."

    local templates=("CLAUDE.md" "git-tags.md" "settings.json" "PROJECT_CONFIG.md")

    for template in "${templates[@]}"; do
        local sdk_file="$AGENTIZE_ROOT/claude/templates/${template}.template"
        local target_file="$MASTER_PROJ/.claude/$template"

        # Check if template exists in SDK
        if [ ! -f "$sdk_file" ]; then
            continue
        fi

        # Check if target file exists
        if [ ! -f "$target_file" ]; then
            log_info "Target file does not exist: $template (skipping)"
            continue
        fi

        # Compare files (ignore template if identical)
        if diff -q "$sdk_file" "$target_file" >/dev/null 2>&1; then
            continue
        fi

        # Files differ - prompt user
        log_warning "Template file changed: $template"
        while true; do
            echo ""
            echo "  [s]kip  [o]verwrite  [d]iff  [q]uit"
            read -p "Choice: " choice

            case "$choice" in
                s|S)
                    log_info "Skipped: $template"
                    break
                    ;;
                o|O)
                    cp "$sdk_file" "$target_file"
                    log_success "Overwrote: $template"
                    break
                    ;;
                d|D)
                    echo ""
                    echo "Diff (current vs SDK template):"
                    diff -u "$target_file" "$sdk_file" | head -50 || true
                    echo ""
                    ;;
                q|Q)
                    log_info "User quit during templated file handling"
                    exit 0
                    ;;
                *)
                    log_error "Invalid choice: $choice"
                    ;;
            esac
        done
    done

    log_success "Templated files handled"
}

# ============================================================================
# Language Template Copying
# ============================================================================

copy_language_template() {
    if [ "$MODE" != "init" ]; then
        return
    fi

    log_info "Copying language-specific project templates..."

    # Get transformed project names
    local proj_snake=$(transform_project_name)
    local proj_cmake=$(transform_project_name_cmake)
    local proj_upper=$(echo "$proj_snake" | tr '[:lower:]' '[:upper:]')

    # Escape special characters for sed
    local proj_name_escaped=$(echo "$PROJ_NAME" | sed 's/[\/&]/\\&/g')
    local proj_snake_escaped=$(echo "$proj_snake" | sed 's/[\/&]/\\&/g')
    local proj_cmake_escaped=$(echo "$proj_cmake" | sed 's/[\/&]/\\&/g')
    local proj_upper_escaped=$(echo "$proj_upper" | sed 's/[\/&]/\\&/g')

    # Helper function to process a single file
    process_template_file() {
        local src_file="$1"
        local dest_file="$2"

        # Skip Makefile.template files (they are concatenated into main Makefile)
        if [ "$(basename "$src_file")" = "Makefile.template" ]; then
            return 0
        fi

        # Replace directory names
        dest_file=$(echo "$dest_file" | sed "s/__NAME__/$proj_snake/g")

        # Create parent directory if needed
        mkdir -p "$(dirname "$dest_file")"

        # Skip if destination already exists
        if [ -f "$dest_file" ]; then
            log_info "Skipping existing file: $(basename "$dest_file")"
            return 0
        fi

        # Process file content with substitutions
        sed -e "s/\${PROJECT_NAME}/$proj_name_escaped/g" \
            -e "s/__PROJECT_NAME__/$proj_cmake_escaped/g" \
            -e "s/__NAME_UPPER__/$proj_upper_escaped/g" \
            -e "s/__NAME__/$proj_snake_escaped/g" \
            "$src_file" > "$dest_file"

        # Preserve executable bit
        if [ -x "$src_file" ]; then
            chmod +x "$dest_file"
        fi

        return 0
    }

    # Copy Python template
    if $HAS_PYTHON; then
        log_info "Copying Python project template..."
        local template_dir="$AGENTIZE_ROOT/templates/python"

        if [ -d "$template_dir" ]; then
            # Find all files in template directory
            while IFS= read -r -d '' file; do
                local rel_path="${file#$template_dir/}"
                local dest_path="$MASTER_PROJ/$rel_path"
                process_template_file "$file" "$dest_path"
            done < <(find "$template_dir" -type f -print0)

            log_success "Python template copied"
        else
            log_warning "Python template directory not found: $template_dir"
        fi
    fi

    # Copy C++ template
    if $HAS_CPP; then
        log_info "Copying C++ project template..."
        local template_dir="$AGENTIZE_ROOT/templates/cxx"

        if [ -d "$template_dir" ]; then
            while IFS= read -r -d '' file; do
                local rel_path="${file#$template_dir/}"
                local dest_path="$MASTER_PROJ/$rel_path"
                process_template_file "$file" "$dest_path"
            done < <(find "$template_dir" -type f -print0)

            log_success "C++ template copied"
        else
            log_warning "C++ template directory not found: $template_dir"
        fi
    fi

    # Copy C template
    if $HAS_C; then
        log_info "Copying C project template..."
        local template_dir="$AGENTIZE_ROOT/templates/c"

        if [ -d "$template_dir" ]; then
            while IFS= read -r -d '' file; do
                local rel_path="${file#$template_dir/}"
                local dest_path="$MASTER_PROJ/$rel_path"
                process_template_file "$file" "$dest_path"
            done < <(find "$template_dir" -type f -print0)

            log_success "C template copied"
        else
            log_warning "C template directory not found: $template_dir"
        fi
    fi

    # Initialize Rust project
    if $HAS_RUST; then
        log_info "Initializing Rust project with cargo..."

        if command -v cargo &> /dev/null; then
            (cd "$MASTER_PROJ" && cargo init --name "$proj_snake" --quiet 2>/dev/null || cargo init --name "$proj_snake")
            log_success "Rust project initialized"
        else
            log_warning "cargo not found, skipping Rust initialization"
            log_warning "Install Rust from https://rustup.rs/"
        fi
    fi
}

# ============================================================================
# Template Processing
# ============================================================================

process_templates() {
    log_info "Processing templates with project-specific values..."

    # Escape special characters for sed
    PROJ_NAME_ESCAPED=$(echo "$PROJ_NAME" | sed 's/[\/&]/\\&/g')
    MASTER_PROJ_ESCAPED=$(echo "$MASTER_PROJ" | sed 's/[\/&]/\\&/g')

    # Process CLAUDE.md template
    if [ -f "$AGENTIZE_ROOT/claude/templates/CLAUDE.md.template" ]; then
        sed -e "s/\${PROJECT_NAME}/$PROJ_NAME_ESCAPED/g" \
            "$AGENTIZE_ROOT/claude/templates/CLAUDE.md.template" \
            > "$MASTER_PROJ/.claude/CLAUDE.md"
        log_success "Created .claude/CLAUDE.md"
    fi

    # Process git-tags.template.md
    if [ -f "$AGENTIZE_ROOT/claude/templates/git-tags.template.md" ]; then
        sed -e "s/\${PROJECT_NAME}/$PROJ_NAME_ESCAPED/g" \
            "$AGENTIZE_ROOT/claude/templates/git-tags.template.md" \
            > "$MASTER_PROJ/.claude/git-tags.md"
        log_success "Created .claude/git-tags.md"
    fi

    # Process settings.json template
    if [ -f "$AGENTIZE_ROOT/claude/templates/settings.json.template" ]; then
        sed -e "s/\${PROJECT_NAME}/$PROJ_NAME_ESCAPED/g" \
            -e "s|\${MASTER_PROJ}|$MASTER_PROJ_ESCAPED|g" \
            "$AGENTIZE_ROOT/claude/templates/settings.json.template" \
            > "$MASTER_PROJ/.claude/settings.json"
        log_success "Created .claude/settings.json"
    fi

    # Copy PROJECT_CONFIG.md (no substitution needed)
    if [ -f "$AGENTIZE_ROOT/claude/templates/PROJECT_CONFIG.md" ]; then
        cp "$AGENTIZE_ROOT/claude/templates/PROJECT_CONFIG.md" \
           "$MASTER_PROJ/.claude/PROJECT_CONFIG.md"
        log_success "Created .claude/PROJECT_CONFIG.md"
    fi
}

# ============================================================================
# Update Mode Orchestration
# ============================================================================

# Main update mode workflow
update_mode() {
    log_info "Starting SDK update mode..."

    # Step 1: Validate that .claude/ exists
    validate_update_target

    # Step 2: Create backup before any modifications
    create_backup

    # Step 3: Update SDK-owned directories
    update_sdk_directories

    # Step 4: Update SDK-owned rules selectively
    update_sdk_rules

    # Step 5: Handle templated files interactively
    handle_templated_files

    # Step 6: Report orphaned files
    report_orphaned_files

    log_success "Update mode complete!"
}

# ============================================================================
# Mode-Specific Initialization
# ============================================================================

initialize_project() {
    if [ "$MODE" = "init" ]; then
        log_info "Initializing new project structure (mode: init)..."

        # Create docs/ folder with docs/CLAUDE.md
        mkdir -p "$MASTER_PROJ/docs"
        if [ -f "$AGENTIZE_ROOT/claude/templates/docs-CLAUDE.md.template" ]; then
            sed -e "s/\${PROJECT_NAME}/$PROJ_NAME_ESCAPED/g" \
                "$AGENTIZE_ROOT/claude/templates/docs-CLAUDE.md.template" \
                > "$MASTER_PROJ/docs/CLAUDE.md"
            log_success "Created docs/CLAUDE.md"
        fi

        # Create README.md stub
        if [ ! -f "$MASTER_PROJ/README.md" ] && [ -f "$AGENTIZE_ROOT/claude/templates/project-README.md.template" ]; then
            sed -e "s/\${PROJECT_NAME}/$PROJ_NAME_ESCAPED/g" \
                "$AGENTIZE_ROOT/claude/templates/project-README.md.template" \
                > "$MASTER_PROJ/README.md"
            log_success "Created README.md"
        else
            log_info "README.md already exists, skipping"
        fi

        # Create .gitignore
        if [ ! -f "$MASTER_PROJ/.gitignore" ] && [ -f "$AGENTIZE_ROOT/claude/templates/project-gitignore.template" ]; then
            cp "$AGENTIZE_ROOT/claude/templates/project-gitignore.template" \
               "$MASTER_PROJ/.gitignore"
            log_success "Created .gitignore"
        else
            log_info ".gitignore already exists, skipping"
        fi

        # Create setup.sh template
        if [ ! -f "$MASTER_PROJ/setup.sh" ] && [ -f "$AGENTIZE_ROOT/claude/templates/project-setup.sh.template" ]; then
            cp "$AGENTIZE_ROOT/claude/templates/project-setup.sh.template" \
               "$MASTER_PROJ/setup.sh"
            chmod +x "$MASTER_PROJ/setup.sh"
            log_success "Created setup.sh"
        else
            log_info "setup.sh already exists, skipping"
        fi

    elif [ "$MODE" = "port" ]; then
        log_info "Porting to existing project (mode: port) - .claude/ only"
    fi
}

# ============================================================================
# Enhanced Makefile Generation
# ============================================================================

generate_enhanced_makefile() {
    if [ "$MODE" != "init" ]; then
        return
    fi

    if [ -f "$MASTER_PROJ/Makefile" ]; then
        log_info "Makefile already exists, skipping generation"
        return
    fi

    log_info "Generating language-aware Makefile..."

    # Collect build/test/clean/lint dependencies
    local build_deps=""
    local test_deps=""
    local clean_deps=""
    local lint_deps=""

    $HAS_PYTHON && build_deps="${build_deps} build-python"
    $HAS_C && build_deps="${build_deps} build-c"
    $HAS_CPP && build_deps="${build_deps} build-cxx"
    $HAS_RUST && build_deps="${build_deps} build-rust"

    $HAS_PYTHON && test_deps="${test_deps} test-python"
    $HAS_C && test_deps="${test_deps} test-c"
    $HAS_CPP && test_deps="${test_deps} test-cxx"
    $HAS_RUST && test_deps="${test_deps} test-rust"

    $HAS_PYTHON && clean_deps="${clean_deps} clean-python"
    $HAS_C && clean_deps="${clean_deps} clean-c"
    $HAS_CPP && clean_deps="${clean_deps} clean-cxx"
    $HAS_RUST && clean_deps="${clean_deps} clean-rust"

    $HAS_PYTHON && lint_deps="${lint_deps} lint-python"
    $HAS_C && lint_deps="${lint_deps} lint-c"
    $HAS_CPP && lint_deps="${lint_deps} lint-cxx"
    $HAS_RUST && lint_deps="${lint_deps} lint-rust"

    # Create Makefile header
    cat > "$MASTER_PROJ/Makefile" <<EOF
# ============================================================================
# ${PROJ_NAME} - Makefile
# ============================================================================

.PHONY: help
help:
	@echo "=============================="
	@echo "${PROJ_NAME}"
	@echo "=============================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help   - Show this help message"
	@echo "  build  - Build the project"
	@echo "  test   - Run all tests"
	@echo "  clean  - Clean build artifacts"
	@echo "  lint   - Run linters"
	@echo "  env    - Print shell exports (use: eval \$(make env))"
	@echo "  env-script - Generate setup.sh for environment setup"
	@echo ""

.PHONY: build
build:${build_deps}

.PHONY: test
test:${test_deps}

.PHONY: clean
clean:${clean_deps}
	@rm -f setup.sh
	@echo "✓ Clean complete"

.PHONY: lint
lint:${lint_deps}

# ============================================================================
# Environment Setup Targets
# ============================================================================

.PHONY: env
env:
	@echo "export PROJECT_ROOT=\"\$(CURDIR)\""
	@echo "export PATH=\"\$(CURDIR)/build/bin:\$\$PATH\""
EOF

    # Conditional: Python environment variables
    if $HAS_PYTHON; then
        cat >> "$MASTER_PROJ/Makefile" <<'EOF'
	@echo "export PYTHONPATH=\"$(CURDIR)/src:$$PYTHONPATH\""
EOF
    fi

    # Conditional: Rust environment variables
    if $HAS_RUST; then
        cat >> "$MASTER_PROJ/Makefile" <<'EOF'
	@echo "export CARGO_TARGET_DIR=\"$(CURDIR)/target\""
EOF
    fi

    # Resume main heredoc for env-script target
    cat >> "$MASTER_PROJ/Makefile" <<EOF

.PHONY: env-script
env-script:
	@echo "#!/bin/bash" > setup.sh
	@echo "# Auto-generated environment setup for ${PROJ_NAME}" >> setup.sh
	@echo "# Generated: \$\$(date)" >> setup.sh
	@echo "" >> setup.sh
	@echo "PROJECT_ROOT=\"\$(CURDIR)\"" >> setup.sh
	@echo "export PROJECT_ROOT" >> setup.sh
	@echo "export PATH=\"\\\$\$PROJECT_ROOT/build/bin:\\\$\$PATH\"" >> setup.sh
EOF

    # Add Python environment variables to setup.sh
    if $HAS_PYTHON; then
        cat >> "$MASTER_PROJ/Makefile" <<'EOF'
	@echo "export PYTHONPATH=\"\$$PROJECT_ROOT/src:\$$PYTHONPATH\"" >> setup.sh
EOF
    fi

    # Add Rust environment variables to setup.sh
    if $HAS_RUST; then
        cat >> "$MASTER_PROJ/Makefile" <<'EOF'
	@echo "export CARGO_TARGET_DIR=\"\$$PROJECT_ROOT/target\"" >> setup.sh
EOF
    fi

    # Finalize setup.sh creation
    cat >> "$MASTER_PROJ/Makefile" <<EOF
	@chmod +x setup.sh
	@echo "✓ Created setup.sh (use: source setup.sh)"

# ============================================================================
# Language-Specific Targets
# ============================================================================

EOF

    # Append language-specific Makefile templates
    if $HAS_PYTHON; then
        if [ -f "$AGENTIZE_ROOT/templates/python/Makefile.template" ]; then
            cat "$AGENTIZE_ROOT/templates/python/Makefile.template" >> "$MASTER_PROJ/Makefile"
            echo "" >> "$MASTER_PROJ/Makefile"
        fi
    fi

    if $HAS_C; then
        if [ -f "$AGENTIZE_ROOT/templates/c/Makefile.template" ]; then
            cat "$AGENTIZE_ROOT/templates/c/Makefile.template" >> "$MASTER_PROJ/Makefile"
            echo "" >> "$MASTER_PROJ/Makefile"
        fi
    fi

    if $HAS_CPP; then
        if [ -f "$AGENTIZE_ROOT/templates/cxx/Makefile.template" ]; then
            cat "$AGENTIZE_ROOT/templates/cxx/Makefile.template" >> "$MASTER_PROJ/Makefile"
            echo "" >> "$MASTER_PROJ/Makefile"
        fi
    fi

    if $HAS_RUST; then
        if [ -f "$AGENTIZE_ROOT/templates/rust/Makefile.template" ]; then
            cat "$AGENTIZE_ROOT/templates/rust/Makefile.template" >> "$MASTER_PROJ/Makefile"
            echo "" >> "$MASTER_PROJ/Makefile"
        fi
    fi

    # Add default goal
    echo ".DEFAULT_GOAL := help" >> "$MASTER_PROJ/Makefile"

    log_success "Created language-aware Makefile"
}

# ============================================================================
# Gitignore Enhancement
# ============================================================================

append_gitignore_patterns() {
    if [ "$MODE" != "init" ]; then
        return
    fi

    if [ ! -f "$MASTER_PROJ/.gitignore" ]; then
        return
    fi

    log_info "Appending language-specific .gitignore patterns..."

    local patterns_added=false

    # Python patterns
    if $HAS_PYTHON; then
        if ! grep -q "__pycache__" "$MASTER_PROJ/.gitignore" 2>/dev/null; then
            cat >> "$MASTER_PROJ/.gitignore" <<'EOF'

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
ENV/
.pytest_cache/
.coverage
htmlcov/
dist/
build/
*.egg-info/
EOF
            patterns_added=true
        fi
    fi

    # C/C++ patterns
    if $HAS_CPP || $HAS_C; then
        if ! grep -q "CMakeCache.txt" "$MASTER_PROJ/.gitignore" 2>/dev/null; then
            cat >> "$MASTER_PROJ/.gitignore" <<'EOF'

# C/C++
*.o
*.a
*.so
*.exe
*.out
build/
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
Makefile.cmake
CTestTestfile.cmake
compile_commands.json
EOF
            patterns_added=true
        fi
    fi

    # Rust patterns
    if $HAS_RUST; then
        if ! grep -q "target/" "$MASTER_PROJ/.gitignore" 2>/dev/null; then
            cat >> "$MASTER_PROJ/.gitignore" <<'EOF'

# Rust
target/
Cargo.lock
**/*.rs.bk
EOF
            patterns_added=true
        fi
    fi

    if $patterns_added; then
        log_success "Added language-specific .gitignore patterns"
    else
        log_info "Language-specific patterns already present in .gitignore"
    fi
}

# ============================================================================
# Summary
# ============================================================================

print_summary() {
    echo ""

    if [ "$MODE" = "update" ]; then
        # Update mode summary
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}SDK Update Complete!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Project: $PROJ_NAME"
        echo "Location: $MASTER_PROJ"
        echo ""
        echo "Your .claude/ configuration has been updated to the latest SDK version."
        echo "User customizations have been preserved."
        echo ""
        echo -e "${BLUE}Backup:${NC}"
        echo "  Location: $BACKUP_DIR"
        echo ""
        echo -e "${BLUE}Rollback procedure (if needed):${NC}"
        echo "  rm -rf $MASTER_PROJ/.claude"
        echo "  mv $BACKUP_DIR $MASTER_PROJ/.claude"
        echo ""
        echo -e "${BLUE}Updated components:${NC}"
        echo "  • $(ls -1 "$MASTER_PROJ/.claude/agents"/*.md 2>/dev/null | wc -l | tr -d ' ') agents"
        echo "  • $(ls -1 "$MASTER_PROJ/.claude/commands"/*.md 2>/dev/null | wc -l | tr -d ' ') commands"
        echo "  • $(ls -1 "$MASTER_PROJ/.claude/rules"/*.md 2>/dev/null | wc -l | tr -d ' ') rules"
        echo "  • $(ls -1 "$MASTER_PROJ/.claude/skills"/*.md 2>/dev/null | wc -l | tr -d ' ') skills"
        echo ""
    else
        # Init/Port mode summary
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Installation Complete!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Project: $PROJ_NAME"
        echo "Location: $MASTER_PROJ"
        echo "Mode: $MODE"
        echo ""
        echo "Installed components:"
        echo "  • $(ls -1 "$MASTER_PROJ/.claude/agents"/*.md 2>/dev/null | wc -l | tr -d ' ') agents"
        echo "  • $(ls -1 "$MASTER_PROJ/.claude/commands"/*.md 2>/dev/null | wc -l | tr -d ' ') commands"
        echo "  • $(ls -1 "$MASTER_PROJ/.claude/rules"/*.md 2>/dev/null | wc -l | tr -d ' ') rules"
        echo "  • $(ls -1 "$MASTER_PROJ/.claude/skills"/*.md 2>/dev/null | wc -l | tr -d ' ') skills"

        if [ "$MODE" = "init" ]; then
            echo ""
            echo "Initialized project files:"
            [ -d "$MASTER_PROJ/docs" ] && echo "  • docs/ folder"
            [ -f "$MASTER_PROJ/docs/CLAUDE.md" ] && echo "  • docs/CLAUDE.md"
            [ -f "$MASTER_PROJ/Makefile" ] && echo "  • Makefile"
            [ -f "$MASTER_PROJ/README.md" ] && echo "  • README.md"
            [ -f "$MASTER_PROJ/.gitignore" ] && echo "  • .gitignore"
            [ -f "$MASTER_PROJ/setup.sh" ] && echo "  • setup.sh"
        fi

        echo ""
        echo -e "${BLUE}Next steps:${NC}"
        echo "  1. cd $MASTER_PROJ"
        echo "  2. Review .claude/CLAUDE.md and customize for your project"
        echo "  3. Customize .claude/git-tags.md with your project's component tags"
        echo "  4. Check .claude/PROJECT_CONFIG.md for configuration guide"
        if [ "$MODE" = "init" ]; then
            echo "  5. Run 'make build' to build your project"
            echo "  6. Run 'make test' to run tests"
            echo "  7. Update docs/CLAUDE.md with your project documentation"
        else
            echo "  5. Ensure your project has: make build, make test, source setup.sh"
        fi
        echo ""
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo ""
    echo "Agentize SDK Installer"
    echo "======================"
    echo ""

    if [ "$MODE" = "update" ]; then
        # Update mode: Different workflow
        update_mode
        print_summary
    else
        # Init/Port mode: Original workflow
        validate_target_project
        detect_languages
        create_directory_structure
        copy_components
        process_templates
        copy_language_template
        initialize_project
        generate_enhanced_makefile
        append_gitignore_patterns
        print_summary
    fi
}

main
