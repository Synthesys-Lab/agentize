#!/usr/bin/env bash
# Wrapper around gh api graphql that supports fixture mode for testing
# When AGENTIZE_GH_API=fixture, returns mock data instead of making live API calls

set -e

# Check if we're in fixture mode
if [ "$AGENTIZE_GH_API" = "fixture" ]; then
    FIXTURE_MODE=1
else
    FIXTURE_MODE=0
fi

# Find the fixtures directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures/github-projects"

# Return fixture data for testing
return_fixture() {
    local operation="$1"
    local fixture_file=""

    case "$operation" in
        create-project)
            fixture_file="$FIXTURES_DIR/create-project-response.json"
            ;;
        lookup-project)
            fixture_file="$FIXTURES_DIR/lookup-project-response.json"
            ;;
        add-item)
            fixture_file="$FIXTURES_DIR/add-item-response.json"
            ;;
        list-fields)
            fixture_file="$FIXTURES_DIR/list-fields-response.json"
            ;;
        create-field)
            fixture_file="$FIXTURES_DIR/create-field-response.json"
            ;;
        *)
            echo "Error: Unknown fixture operation '$operation'" >&2
            exit 1
            ;;
    esac

    if [ ! -f "$fixture_file" ]; then
        echo "Error: Fixture file not found: $fixture_file" >&2
        exit 1
    fi

    cat "$fixture_file"
}

# Execute GraphQL query for create-project
graphql_create_project() {
    local owner_id="$1"
    local title="$2"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "create-project"
        return 0
    fi

    gh api graphql -f query='
        mutation($ownerId: ID!, $title: String!) {
            createProjectV2(input: {ownerId: $ownerId, title: $title}) {
                projectV2 {
                    id
                    number
                    title
                    url
                }
            }
        }' -f ownerId="$owner_id" -f title="$title"
}

# Execute GraphQL query for lookup-project
graphql_lookup_project() {
    local org="$1"
    local project_number="$2"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "lookup-project"
        return 0
    fi

    gh api graphql -f query='
        query($org: String!, $number: Int!) {
            organization(login: $org) {
                projectV2(number: $number) {
                    id
                    number
                    title
                    url
                }
            }
        }' -f org="$org" -F number="$project_number"
}

# Execute GraphQL query for add-item
graphql_add_item() {
    local project_id="$1"
    local content_id="$2"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "add-item"
        return 0
    fi

    gh api graphql -f query='
        mutation($projectId: ID!, $contentId: ID!) {
            addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
                item {
                    id
                }
            }
        }' -f projectId="$project_id" -f contentId="$content_id"
}

# Execute GraphQL query for list-fields
graphql_list_fields() {
    local project_id="$1"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "list-fields"
        return 0
    fi

    gh api graphql -f query='
        query($projectId: ID!) {
            node(id: $projectId) {
                ... on ProjectV2 {
                    fields(first: 20) {
                        nodes {
                            ... on ProjectV2SingleSelectField {
                                id
                                name
                                options {
                                    id
                                    name
                                }
                            }
                        }
                    }
                }
            }
        }' -f projectId="$project_id"
}

# Execute GraphQL query for create-field
graphql_create_field() {
    local project_id="$1"
    local field_name="$2"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "create-field"
        return 0
    fi

    gh api graphql -f query='
        mutation($projectId: ID!, $name: String!) {
            createProjectV2Field(
                input: {
                    projectId: $projectId
                    dataType: SINGLE_SELECT
                    name: $name
                    singleSelectOptions: [
                        { name: "proposed" }
                        { name: "accepted" }
                    ]
                }
            ) {
                projectV2Field {
                    ... on ProjectV2SingleSelectField {
                        id
                        name
                        options {
                            id
                            name
                        }
                    }
                }
            }
        }' -f projectId="$project_id" -f name="$field_name"
}

# Main execution
main() {
    local operation="$1"
    shift

    case "$operation" in
        create-project)
            graphql_create_project "$@"
            ;;
        lookup-project)
            graphql_lookup_project "$@"
            ;;
        add-item)
            graphql_add_item "$@"
            ;;
        list-fields)
            graphql_list_fields "$@"
            ;;
        create-field)
            graphql_create_field "$@"
            ;;
        *)
            echo "Error: Unknown operation '$operation'" >&2
            echo "" >&2
            echo "Usage:" >&2
            echo "  $0 create-project <owner-id> <title>" >&2
            echo "  $0 lookup-project <org> <project-number>" >&2
            echo "  $0 add-item <project-id> <content-id>" >&2
            echo "  $0 list-fields <project-id>" >&2
            echo "  $0 create-field <project-id> <field-name>" >&2
            exit 1
            ;;
    esac
}

main "$@"
