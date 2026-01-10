#!/usr/bin/env bash
# lol_cmd_project: GitHub Projects v2 integration

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
