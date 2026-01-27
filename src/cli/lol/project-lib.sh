#!/usr/bin/env bash
# Shared project library for GitHub Projects v2 operations
# Used by both lol project command and /setup-viewboard command

# Guard against multiple sourcing
if [ -n "$_PROJECT_LIB_LOADED" ]; then
    return 0
fi
_PROJECT_LIB_LOADED=1

# Required Status field options for agentize workflow (newline-separated for multi-word options)
AGENTIZE_REQUIRED_STATUS_OPTIONS="Proposed
Refining
Rebasing
Plan Accepted
In Progress
Done"

# Initialize project context variables
# Sets: PROJECT_ROOT, METADATA_FILE
# Returns: 0 on success, 1 on failure
project_init_context() {
    PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "Error: Not in a git repository" >&2
        return 1
    }
    METADATA_FILE="$PROJECT_ROOT/.agentize.yaml"
    export PROJECT_ROOT METADATA_FILE
}

# Preflight check for gh CLI availability and authentication
# Skip in fixture mode for testing
# Returns: 0 on success, exits on failure
project_preflight_check() {
    # Skip preflight in fixture mode (tests use fixtures, not live gh auth)
    if [ "$AGENTIZE_GH_API" = "fixture" ]; then
        return 0
    fi

    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI (gh) is not installed"
        echo ""
        echo "Please install gh:"
        echo "  https://cli.github.com/manual/installation"
        return 1
    fi

    if ! gh auth status &> /dev/null; then
        echo "Error: GitHub CLI is not authenticated"
        echo ""
        echo "Please authenticate gh:"
        echo "  gh auth login"
        return 1
    fi
}

# Read value from .agentize.yaml under project: section
# Usage: project_read_metadata <key>
# Returns: value on stdout, exit 0 on found, exit 1 on not found
project_read_metadata() {
    local key="$1"
    if [ ! -f "$METADATA_FILE" ]; then
        return 1
    fi
    local value
    value="$(grep "^  $key:" "$METADATA_FILE" | sed "s/^  $key: *//" | head -1)"
    if [ -z "$value" ]; then
        return 1
    fi
    echo "$value"
}

# Update or add a field in .agentize.yaml under the project: section
# Usage: project_update_metadata <key> <value>
# Returns: 0 on success, exits on failure
project_update_metadata() {
    local key="$1"
    local value="$2"

    if [ ! -f "$METADATA_FILE" ]; then
        echo "Error: .agentize.yaml not found"
        echo ""
        echo "Please create .agentize.yaml manually or see docs/architecture/metadata.md for details."
        return 1
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

# Create a new GitHub Projects v2 board
# Usage: project_create [owner] [title]
# Outputs: Project URL on success
# Updates: .agentize.yaml with project.org and project.id
project_create() {
    local owner="$1"
    local title="$2"

    # Default owner to repository owner
    if [ -z "$owner" ]; then
        owner="$(gh repo view --json owner --jq '.owner.login' 2>/dev/null)" || {
            echo "Error: Unable to detect repository owner"
            echo ""
            echo "Please specify --org explicitly"
            return 1
        }
    fi

    # Default title to repository name
    if [ -z "$title" ]; then
        title="$(basename "$PROJECT_ROOT")"
    fi

    echo "Creating GitHub Projects v2 board:"
    echo "  Owner: $owner"
    echo "  Title: $title"
    echo ""

    # Get owner ID for GraphQL mutation using lookup-owner
    local owner_result owner_id owner_type
    owner_result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" lookup-owner "$owner")" || {
        echo "Error: Unable to access owner '$owner'"
        echo ""
        echo "Please ensure:"
        echo "  1. Owner (organization or user) exists"
        echo "  2. You have access to the owner"
        echo "  3. gh CLI has required permissions"
        return 1
    }

    owner_id="$(echo "$owner_result" | jq -r '.data.repositoryOwner.id')"
    owner_type="$(echo "$owner_result" | jq -r '.data.repositoryOwner.__typename')"

    if [ -z "$owner_id" ] || [ "$owner_id" = "null" ]; then
        echo "Error: Owner '$owner' not found"
        return 1
    fi

    # Create project via GraphQL
    local result
    result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" create-project "$owner_id" "$title")" || {
        echo "Error: Failed to create project"
        return 1
    }

    local project_number project_url
    project_number="$(echo "$result" | jq -r '.data.createProjectV2.projectV2.number')"
    project_url="$(echo "$result" | jq -r '.data.createProjectV2.projectV2.url')"

    if [ -z "$project_number" ] || [ "$project_number" = "null" ]; then
        echo "Error: Failed to extract project number from GraphQL response"
        return 1
    fi

    echo "Project created successfully: $owner/$project_number"
    echo ""

    # Update metadata
    project_update_metadata "org" "$owner"
    project_update_metadata "id" "$project_number"

    echo "Updated .agentize.yaml"
    echo ""
    echo "Project association complete."
    echo ""

    # Return project URL
    if [ -n "$project_url" ] && [ "$project_url" != "null" ]; then
        echo "Project URL: $project_url"
    else
        # Fallback: determine path based on owner type
        local owner_path="orgs"
        if [ "$owner_type" = "User" ]; then
            owner_path="users"
        fi
        echo "Project URL: https://github.com/$owner_path/$owner/projects/$project_number"
    fi
}

# Associate with an existing GitHub Projects v2 board
# Usage: project_associate <owner/id>
# Outputs: Project URL on success
# Updates: .agentize.yaml with project.org and project.id
project_associate() {
    local associate_arg="$1"

    if [ -z "$associate_arg" ]; then
        echo "Error: associate requires <owner>/<id> argument"
        return 1
    fi

    # Parse owner/id
    local owner="${associate_arg%%/*}"
    local project_id="${associate_arg##*/}"

    if [ -z "$owner" ] || [ -z "$project_id" ]; then
        echo "Error: Invalid format for associate argument"
        echo "Expected: <owner>/<id> (e.g., Synthesys-Lab/3 or my-username/1)"
        echo "Got: $associate_arg"
        return 1
    fi

    echo "Associating with GitHub Projects v2 board:"
    echo "  Owner: $owner"
    echo "  Project ID: $project_id"
    echo ""

    # Verify project exists via GraphQL (uses repositoryOwner which works for both orgs and users)
    local result
    result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" lookup-project "$owner" "$project_id")" || {
        echo "Error: Failed to look up project"
        return 1
    }

    # Extract from repositoryOwner path (works for both Organization and User)
    local project_title project_url
    project_title="$(echo "$result" | jq -r '.data.repositoryOwner.projectV2.title')"
    project_url="$(echo "$result" | jq -r '.data.repositoryOwner.projectV2.url')"

    if [ -z "$project_title" ] || [ "$project_title" = "null" ]; then
        echo "Error: Project $owner/$project_id not found or inaccessible"
        echo ""
        echo "Please ensure:"
        echo "  1. Project exists"
        echo "  2. You have access to the project"
        echo "  3. Project number is correct (not node_id)"
        return 1
    fi

    echo "Found project: $project_title"
    echo ""

    # Update metadata
    project_update_metadata "org" "$owner"
    project_update_metadata "id" "$project_id"

    echo "Updated .agentize.yaml"
    echo ""
    echo "Project association complete."
    echo ""

    # Return project URL
    if [ -n "$project_url" ] && [ "$project_url" != "null" ]; then
        echo "Project URL: $project_url"
    else
        # Determine owner type for correct URL path
        local owner_result owner_type owner_path
        owner_result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" lookup-owner "$owner" 2>/dev/null)" || true
        owner_type="$(echo "$owner_result" | jq -r '.data.repositoryOwner.__typename' 2>/dev/null)"
        owner_path="orgs"
        if [ "$owner_type" = "User" ]; then
            owner_path="users"
        fi
        echo "Project URL: https://github.com/$owner_path/$owner/projects/$project_id"
    fi
}

# Generate automation workflow template
# Usage: project_generate_automation [write_path]
# If write_path is provided, writes to file; otherwise prints to stdout
project_generate_automation() {
    local write_path="$1"

    # Read project metadata
    local owner project_id
    owner="$(project_read_metadata "org")" || owner=""
    project_id="$(project_read_metadata "id")" || project_id=""

    # Use defaults if not set
    if [ -z "$owner" ]; then
        owner="YOUR_OWNER_HERE"
    fi
    if [ -z "$project_id" ]; then
        project_id="YOUR_PROJECT_ID_HERE"
    fi

    # Detect owner type for correct URL path (orgs/ vs users/)
    local owner_path="orgs"
    local owner_type=""

    # Check Status field configuration
    if [ "$owner" != "YOUR_OWNER_HERE" ] && [ "$project_id" != "YOUR_PROJECT_ID_HERE" ]; then
        echo "Configuring Status field for project automation..."
        echo ""

        # Get owner type first
        local owner_result
        owner_result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" lookup-owner "$owner" 2>/dev/null)" || true
        if [ -n "$owner_result" ]; then
            owner_type="$(echo "$owner_result" | jq -r '.data.repositoryOwner.__typename')"
            if [ "$owner_type" = "User" ]; then
                owner_path="users"
            fi
        fi

        # Get project GraphQL ID
        local result
        result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" lookup-project "$owner" "$project_id")" || {
            echo "Warning: Failed to look up project"
            echo ""
        }

        if [ -n "$result" ]; then
            local project_graphql_id
            # Use repositoryOwner response path
            project_graphql_id="$(echo "$result" | jq -r '.data.repositoryOwner.projectV2.id')"

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

    # Generate workflow content with owner-aware URL path
    local workflow_content
    workflow_content="$(cat "$AGENTIZE_HOME/templates/github/project-auto-add.yml" | \
        sed "s/YOUR_ORG_HERE/$owner/g" | \
        sed "s/YOUR_PROJECT_ID_HERE/$project_id/g" | \
        sed "s|orgs/\${{ env.PROJECT_ORG }}|$owner_path/\${{ env.PROJECT_ORG }}|g")"

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
        echo "1. Create a Classic Personal Access Token (PAT):"
        echo "   - Go to: https://github.com/settings/tokens/new"
        echo "   - Token name: e.g., 'Add to Project Automation'"
        echo "   - Expiration: 90 days (recommended for security)"
        echo "   - Required scopes:"
        echo "     - repo: Read issue/PR data from the repository"
        echo "     - project: Full read/write access to Projects v2 boards"
        echo "     - read:org: Resolve organization-level project URLs"
        echo "   - Click 'Generate token' and copy it (you won't see it again)"
        echo "   Note: Fine-grained PATs are not supported by actions/add-to-project@v1.0.2"
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
        echo "  templates/github/project-auto-add.md"
    else
        # Print to stdout
        echo "$workflow_content"
    fi
}

# Verify and auto-create Status field options
# Usage: project_verify_status_options <owner> <project_id>
# Returns: 0 if all required options present/created, 1 if cannot create with guidance
project_verify_status_options() {
    local owner="$1"
    local project_id="$2"

    if [ -z "$owner" ] || [ -z "$project_id" ]; then
        echo "Error: owner and project_id are required" >&2
        return 1
    fi

    # Get project GraphQL ID
    local result
    result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" lookup-project "$owner" "$project_id")" || {
        echo "Error: Failed to look up project $owner/$project_id" >&2
        return 1
    }

    local project_graphql_id
    project_graphql_id="$(echo "$result" | jq -r '.data.repositoryOwner.projectV2.id')"

    if [ -z "$project_graphql_id" ] || [ "$project_graphql_id" = "null" ]; then
        echo "Error: Project $owner/$project_id not found" >&2
        return 1
    fi

    # List fields to get Status options and field ID
    local fields_result
    fields_result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" list-fields "$project_graphql_id")" || {
        echo "Error: Failed to list project fields" >&2
        return 1
    }

    # Extract Status field ID and options
    local status_field_id configured_options
    status_field_id="$(echo "$fields_result" | jq -r '.data.node.fields.nodes[] | select(.name == "Status") | .id')"
    configured_options="$(echo "$fields_result" | jq -r '.data.node.fields.nodes[] | select(.name == "Status") | .options[].name')"

    if [ -z "$status_field_id" ] || [ "$status_field_id" = "null" ]; then
        echo "Warning: Status field not found in project"
        echo ""
        echo "Please configure the Status field in your project settings."
        return 1
    fi

    # Check for missing required options
    local missing_list=""
    while IFS= read -r required; do
        [ -z "$required" ] && continue
        if ! echo "$configured_options" | grep -qx "$required"; then
            if [ -z "$missing_list" ]; then
                missing_list="$required"
            else
                missing_list="$missing_list
$required"
            fi
        fi
    done <<< "$AGENTIZE_REQUIRED_STATUS_OPTIONS"

    # Report current status
    echo "Configured Status options:"
    if [ -n "$configured_options" ]; then
        echo "$configured_options" | sed 's/^/  - /'
    else
        echo "  (none)"
    fi
    echo ""

    # If missing options, try to create them
    if [ -n "$missing_list" ]; then
        echo "Missing required Status options: $(echo "$missing_list" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')"
        echo ""
        echo "Creating missing options..."
        echo ""

        local creation_failed=""
        while IFS= read -r option_name; do
            [ -z "$option_name" ] && continue
            echo -n "  Creating '$option_name'... "

            if "$AGENTIZE_HOME/scripts/gh-graphql.sh" create-field-option "$status_field_id" "$option_name" "GRAY" >/dev/null 2>&1; then
                echo "done"
            else
                echo "failed"
                if [ -z "$creation_failed" ]; then
                    creation_failed="$option_name"
                else
                    creation_failed="$creation_failed, $option_name"
                fi
            fi
        done <<< "$missing_list"

        echo ""

        if [ -n "$creation_failed" ]; then
            echo "Failed to create options: $creation_failed"
            echo ""
            echo "Please add the missing options manually in your project settings:"

            # Determine URL path based on owner type
            local owner_result owner_type owner_path
            owner_result="$("$AGENTIZE_HOME/scripts/gh-graphql.sh" lookup-owner "$owner" 2>/dev/null)" || true
            owner_type="$(echo "$owner_result" | jq -r '.data.repositoryOwner.__typename' 2>/dev/null)"
            owner_path="orgs"
            if [ "$owner_type" = "User" ]; then
                owner_path="users"
            fi

            echo "  https://github.com/$owner_path/$owner/projects/$project_id/settings"
            echo ""
            echo "Required options for agentize workflow:"
            while IFS= read -r opt; do
                [ -z "$opt" ] && continue
                echo "  - $opt"
            done <<< "$AGENTIZE_REQUIRED_STATUS_OPTIONS"
            return 1
        fi

        echo "All missing Status options created successfully."
        return 0
    fi

    echo "All required Status options are configured."
    return 0
}
