#!/usr/bin/env bash
# GitHub Projects v2 integration for agentize projects
# Handles create, associate, and automation template generation

set -e

# Find project root
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: Not in a git repository"
    echo ""
    echo "Please run this command from within a git repository."
    exit 1
}

# Metadata file path
METADATA_FILE="$PROJECT_ROOT/.agentize.yaml"

# Preflight check: ensure gh CLI is installed and authenticated
preflight_check() {
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

# Read value from .agentize.yaml
read_metadata() {
    local key="$1"
    if [ ! -f "$METADATA_FILE" ]; then
        return 1
    fi
    grep "^  $key:" "$METADATA_FILE" | sed "s/^  $key: *//" | head -1
}

# Update or add a field in .agentize.yaml under the project: section
update_metadata() {
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

# Create a new GitHub Projects v2 board
create_project() {
    local org="$AGENTIZE_PROJECT_ORG"
    local title="$AGENTIZE_PROJECT_TITLE"

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

    echo "✓ Project created successfully: $org/$project_number"
    echo ""

    # Update metadata
    update_metadata "org" "$org"
    update_metadata "id" "$project_number"

    echo "✓ Updated .agentize.yaml"
    echo ""
    echo "Project association complete."
    echo ""
    echo "Next steps:"
    echo "  1. Set up automation: lol project --automation"
    echo "  2. View your project: https://github.com/orgs/$org/projects/$project_number"
}

# Associate with an existing GitHub Projects v2 board
associate_project() {
    local associate_arg="$AGENTIZE_PROJECT_ASSOCIATE"

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

    echo "✓ Found project: $project_title"
    echo ""

    # Update metadata
    update_metadata "org" "$org"
    update_metadata "id" "$project_id"

    echo "✓ Updated .agentize.yaml"
    echo ""
    echo "Project association complete."
    echo ""
    echo "Next steps:"
    echo "  1. Set up automation: lol project --automation"
    echo "  2. View your project: https://github.com/orgs/$org/projects/$project_id"
}

# Generate automation workflow template
generate_automation() {
    local write_path="$AGENTIZE_PROJECT_WRITE_PATH"

    # Read project metadata
    local org
    local project_id
    org="$(read_metadata "org")"
    project_id="$(read_metadata "id")"

    # Use defaults if not set
    if [ -z "$org" ]; then
        org="YOUR_ORG_HERE"
    fi
    if [ -z "$project_id" ]; then
        project_id="YOUR_PROJECT_ID_HERE"
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
        echo "✓ Automation workflow written to: $write_path"
        echo ""
        echo "Next steps:"
        echo "  1. Review the workflow file"
        echo "  2. Create a GitHub Personal Access Token (PAT) with project permissions"
        echo "  3. Add the PAT as a repository secret named ADD_TO_PROJECT_PAT"
        echo "  4. Commit and push the workflow file"
        echo ""
        echo "For detailed setup instructions, see:"
        echo "  docs/workflows/github-projects-automation.md"
    else
        # Print to stdout
        echo "$workflow_content"
    fi
}

# Main execution
main() {
    local mode="$AGENTIZE_PROJECT_MODE"

    case "$mode" in
        create)
            preflight_check
            create_project
            ;;
        associate)
            preflight_check
            associate_project
            ;;
        automation)
            generate_automation
            ;;
        *)
            echo "Error: Invalid mode '$mode'"
            exit 1
            ;;
    esac
}

main
