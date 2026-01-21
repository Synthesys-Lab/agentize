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
# AGENTIZE_GH_OWNER_TYPE can be "user" or "org" (default) to select fixtures
# AGENTIZE_GH_FIXTURE_LIST_FIELDS can be "missing" to simulate missing Status options
return_fixture() {
    local operation="$1"
    local fixture_file=""
    local owner_type="${AGENTIZE_GH_OWNER_TYPE:-org}"

    case "$operation" in
        create-project)
            if [ "$owner_type" = "user" ]; then
                fixture_file="$FIXTURES_DIR/create-project-user-response.json"
            else
                fixture_file="$FIXTURES_DIR/create-project-response.json"
            fi
            ;;
        lookup-owner)
            if [ "$owner_type" = "user" ]; then
                fixture_file="$FIXTURES_DIR/lookup-owner-user-response.json"
            else
                fixture_file="$FIXTURES_DIR/lookup-owner-response.json"
            fi
            ;;
        lookup-project)
            if [ "$owner_type" = "user" ]; then
                fixture_file="$FIXTURES_DIR/lookup-project-user-response.json"
            else
                fixture_file="$FIXTURES_DIR/lookup-project-response.json"
            fi
            ;;
        add-item)
            fixture_file="$FIXTURES_DIR/add-item-response.json"
            ;;
        list-fields)
            # Support fixture override for testing missing Status options
            if [ "$AGENTIZE_GH_FIXTURE_LIST_FIELDS" = "missing" ]; then
                fixture_file="$FIXTURES_DIR/list-fields-missing-response.json"
            else
                fixture_file="$FIXTURES_DIR/list-fields-response.json"
            fi
            ;;
        get-issue-project-item)
            fixture_file="$FIXTURES_DIR/get-issue-project-item-response.json"
            ;;
        update-field)
            fixture_file="$FIXTURES_DIR/update-field-response.json"
            ;;
        create-field-option)
            fixture_file="$FIXTURES_DIR/create-field-option-response.json"
            ;;
        review-threads)
            fixture_file="$FIXTURES_DIR/review-threads-response.json"
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

# Execute GraphQL query for lookup-owner
# Returns the owner ID and type (__typename: Organization or User)
graphql_lookup_owner() {
    local owner="$1"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "lookup-owner"
        return 0
    fi

    gh api graphql -f query='
        query($owner: String!) {
            repositoryOwner(login: $owner) {
                id
                __typename
            }
        }' -f owner="$owner"
}

# Execute GraphQL query for lookup-project
# Uses repositoryOwner which works for both organizations and users
graphql_lookup_project() {
    local owner="$1"
    local project_number="$2"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "lookup-project"
        return 0
    fi

    gh api graphql -f query='
        query($owner: String!, $number: Int!) {
            repositoryOwner(login: $owner) {
                ... on Organization {
                    projectV2(number: $number) {
                        id
                        number
                        title
                        url
                    }
                }
                ... on User {
                    projectV2(number: $number) {
                        id
                        number
                        title
                        url
                    }
                }
            }
        }' -f owner="$owner" -F number="$project_number"
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

# Execute GraphQL query for get-issue-project-item
graphql_get_issue_project_item() {
    local owner="$1"
    local repo="$2"
    local issue_number="$3"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "get-issue-project-item"
        return 0
    fi

    gh api graphql -f query='
        query($owner: String!, $repo: String!, $number: Int!) {
            repository(owner: $owner, name: $repo) {
                issue(number: $number) {
                    id
                    projectItems(first: 20) {
                        nodes {
                            id
                            project {
                                id
                            }
                        }
                    }
                }
            }
        }' -f owner="$owner" -f repo="$repo" -F number="$issue_number"
}

# Execute GraphQL mutation for update-field
graphql_update_field() {
    local project_id="$1"
    local item_id="$2"
    local field_id="$3"
    local option_id="$4"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "update-field"
        return 0
    fi

    gh api graphql -f query='
        mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
            updateProjectV2ItemFieldValue(input: {
                projectId: $projectId,
                itemId: $itemId,
                fieldId: $fieldId,
                value: { singleSelectOptionId: $optionId }
            }) {
                projectV2Item {
                    id
                }
            }
        }' -f projectId="$project_id" -f itemId="$item_id" -f fieldId="$field_id" -f optionId="$option_id"
}

# Execute GraphQL query for review-threads
# Fetches PR review threads with resolution status, path, and line information
graphql_review_threads() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "review-threads"
        return 0
    fi

    gh api graphql -f query='
        query($owner: String!, $repo: String!, $prNumber: Int!) {
            repository(owner: $owner, name: $repo) {
                pullRequest(number: $prNumber) {
                    reviewThreads(first: 100) {
                        nodes {
                            id
                            isResolved
                            isOutdated
                            path
                            line
                            startLine
                            comments(first: 10) {
                                nodes {
                                    id
                                    body
                                    author {
                                        login
                                    }
                                    createdAt
                                }
                            }
                        }
                        pageInfo {
                            hasNextPage
                            endCursor
                        }
                    }
                }
            }
        }' -f owner="$owner" -f repo="$repo" -F prNumber="$pr_number"
}

# Execute GraphQL mutation for create-field-option
# Creates a new option for a single select field (like Status)
graphql_create_field_option() {
    local field_id="$1"
    local option_name="$2"
    local option_color="${3:-GRAY}"

    if [ "$FIXTURE_MODE" = "1" ]; then
        return_fixture "create-field-option"
        return 0
    fi

    gh api graphql -f query='
        mutation($fieldId: ID!, $name: String!, $color: ProjectV2SingleSelectFieldOptionColor!) {
            createProjectV2FieldOption(input: {
                fieldId: $fieldId,
                name: $name,
                color: $color
            }) {
                projectV2SingleSelectFieldOption {
                    id
                    name
                    color
                }
            }
        }' -f fieldId="$field_id" -f name="$option_name" -f color="$option_color"
}

# Main execution
main() {
    local operation="$1"
    shift

    case "$operation" in
        create-project)
            graphql_create_project "$@"
            ;;
        lookup-owner)
            graphql_lookup_owner "$@"
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
        get-issue-project-item)
            graphql_get_issue_project_item "$@"
            ;;
        update-field)
            graphql_update_field "$@"
            ;;
        create-field-option)
            graphql_create_field_option "$@"
            ;;
        review-threads)
            graphql_review_threads "$@"
            ;;
        *)
            echo "Error: Unknown operation '$operation'" >&2
            echo "" >&2
            echo "Usage:" >&2
            echo "  $0 create-project <owner-id> <title>" >&2
            echo "  $0 lookup-owner <owner>" >&2
            echo "  $0 lookup-project <owner> <project-number>" >&2
            echo "  $0 add-item <project-id> <content-id>" >&2
            echo "  $0 list-fields <project-id>" >&2
            echo "  $0 get-issue-project-item <owner> <repo> <issue-number>" >&2
            echo "  $0 update-field <project-id> <item-id> <field-id> <option-id>" >&2
            echo "  $0 create-field-option <field-id> <option-name> [color]" >&2
            echo "  $0 review-threads <owner> <repo> <pr-number>" >&2
            exit 1
            ;;
    esac
}

main "$@"
