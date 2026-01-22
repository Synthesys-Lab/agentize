# gh-graphql.sh

GraphQL wrapper for GitHub Projects v2 API with fixture mode support for testing.

This script provides a unified interface for all GitHub Projects v2 GraphQL operations
used throughout the project. In production mode, it delegates to `gh api graphql`. In
fixture mode (for testing), it returns pre-recorded JSON responses from fixture files.

## External Interface

### Command-line Usage

```bash
./scripts/gh-graphql.sh <operation> [args...]
```

### Operations

#### create-project

Creates a new GitHub Projects v2 project.

```bash
./scripts/gh-graphql.sh create-project <owner-id> <title>
```

**Parameters:**
- `owner-id`: The GraphQL ID of the owner (organization or user)
- `title`: The project title

**Output:** JSON with project ID, number, title, and URL

#### lookup-owner

Looks up a GitHub owner (organization or user) to get their ID and type.

```bash
./scripts/gh-graphql.sh lookup-owner <owner>
```

**Parameters:**
- `owner`: The login name of the organization or user

**Output:** JSON with owner ID and `__typename` (Organization or User)

#### lookup-project

Looks up an existing project by owner and project number.

```bash
./scripts/gh-graphql.sh lookup-project <owner> <project-number>
```

**Parameters:**
- `owner`: The login name of the organization or user
- `project-number`: The project number (visible in project URL)

**Output:** JSON with project ID, number, title, and URL

#### add-item

Adds an issue or pull request to a project.

```bash
./scripts/gh-graphql.sh add-item <project-id> <content-id>
```

**Parameters:**
- `project-id`: The GraphQL ID of the project
- `content-id`: The GraphQL ID of the issue or PR to add

**Output:** JSON with the created item ID

#### list-fields

Lists all single-select fields and their options for a project.

```bash
./scripts/gh-graphql.sh list-fields <project-id>
```

**Parameters:**
- `project-id`: The GraphQL ID of the project

**Output:** JSON with field nodes containing ID, name, and options array

#### get-issue-project-item

Gets project items associated with an issue.

```bash
./scripts/gh-graphql.sh get-issue-project-item <owner> <repo> <issue-number>
```

**Parameters:**
- `owner`: Repository owner
- `repo`: Repository name
- `issue-number`: The issue number

**Output:** JSON with issue ID and project items (each with item ID and project ID)

#### update-field

Updates a single-select field value on a project item.

```bash
./scripts/gh-graphql.sh update-field <project-id> <item-id> <field-id> <option-id>
```

**Parameters:**
- `project-id`: The GraphQL ID of the project
- `item-id`: The GraphQL ID of the project item
- `field-id`: The GraphQL ID of the single-select field
- `option-id`: The GraphQL ID of the option to set

**Output:** JSON with the updated item ID

#### create-field-option

Creates a new option for a single-select field (e.g., adding a new Status value).

```bash
./scripts/gh-graphql.sh create-field-option <field-id> <option-name> [color]
```

**Parameters:**
- `field-id`: The GraphQL ID of the single-select field
- `option-name`: The name for the new option
- `color` (optional): Color for the option (default: GRAY). Valid values: GRAY, BLUE, GREEN, YELLOW, ORANGE, RED, PINK, PURPLE

**Output:** JSON with the created option ID, name, and color

#### review-threads

Fetches review threads from a pull request with resolution status and comments.

```bash
./scripts/gh-graphql.sh review-threads <owner> <repo> <pr-number>
```

**Parameters:**
- `owner`: Repository owner
- `repo`: Repository name
- `pr-number`: The pull request number

**Output:** JSON with review threads containing:
- `id`: Thread ID
- `isResolved`: Whether the thread is resolved
- `isOutdated`: Whether the thread is on outdated code
- `path`: File path
- `line` / `startLine`: Line numbers
- `comments`: Array of comments with author, body, and timestamp

#### resolve-thread

Resolves a single review thread by its GraphQL ID.

```bash
./scripts/gh-graphql.sh resolve-thread <thread-id>
```

**Parameters:**
- `thread-id`: The GraphQL ID of the review thread to resolve

**Output:** JSON with the resolved thread containing:
- `id`: Thread ID
- `isResolved`: Should be `true` after successful resolution

### Environment Variables

#### AGENTIZE_GH_API

Controls whether the script uses live API or fixture mode.

- **Unset or any value except "fixture"**: Live API mode, calls `gh api graphql`
- **"fixture"**: Fixture mode, returns mock data from `tests/fixtures/github-projects/`

```bash
# Live API mode (default)
./scripts/gh-graphql.sh lookup-owner my-org

# Fixture mode for testing
AGENTIZE_GH_API=fixture ./scripts/gh-graphql.sh lookup-owner my-org
```

#### AGENTIZE_GH_OWNER_TYPE

Selects which fixture variant to return for owner-specific operations.

- **Unset or "org"** (default): Returns organization-style fixtures
- **"user"**: Returns user-style fixtures (URLs with `/users/` instead of `/orgs/`)

Affects: `create-project`, `lookup-owner`, `lookup-project`

```bash
# Organization fixtures (default)
AGENTIZE_GH_API=fixture ./scripts/gh-graphql.sh lookup-owner my-org

# User fixtures
AGENTIZE_GH_API=fixture AGENTIZE_GH_OWNER_TYPE=user ./scripts/gh-graphql.sh lookup-owner my-user
```

#### AGENTIZE_GH_FIXTURE_LIST_FIELDS

Selects which fixture variant to return for `list-fields` operation.

- **Unset** (default): Returns standard fixture with all Status options
- **"missing"**: Returns fixture simulating missing Status options (for testing auto-creation)

```bash
# Standard list-fields fixture
AGENTIZE_GH_API=fixture ./scripts/gh-graphql.sh list-fields PVT_xxx

# Missing options fixture
AGENTIZE_GH_API=fixture AGENTIZE_GH_FIXTURE_LIST_FIELDS=missing ./scripts/gh-graphql.sh list-fields PVT_xxx
```

### Exit Codes

- **0**: Operation completed successfully
- **1**: Error occurred:
  - Unknown operation specified
  - Fixture file not found (in fixture mode)
  - GraphQL API error (in live mode)

### Output Format

All operations output JSON to stdout. In live mode, this is the raw GraphQL response
from `gh api graphql`. In fixture mode, this is the contents of the corresponding
fixture file.

Error messages are written to stderr.

## Internal Helpers

### return_fixture(operation)

Dispatches to the appropriate fixture file based on operation name and environment variables.

**Parameters:**
- `operation`: The operation name (e.g., "lookup-owner", "list-fields")

**Behavior:**
1. Determines fixture file path based on operation
2. For operations affected by `AGENTIZE_GH_OWNER_TYPE`, selects user/org variant
3. For `list-fields`, checks `AGENTIZE_GH_FIXTURE_LIST_FIELDS` for variant
4. Outputs fixture file contents to stdout
5. Exits with code 1 if fixture file not found

**Fixture file mapping:**
| Operation | Default Fixture | User Variant | Missing Variant |
|-----------|-----------------|--------------|-----------------|
| create-project | create-project-response.json | create-project-user-response.json | - |
| lookup-owner | lookup-owner-response.json | lookup-owner-user-response.json | - |
| lookup-project | lookup-project-response.json | lookup-project-user-response.json | - |
| add-item | add-item-response.json | - | - |
| list-fields | list-fields-response.json | - | list-fields-missing-response.json |
| get-issue-project-item | get-issue-project-item-response.json | - | - |
| update-field | update-field-response.json | - | - |
| create-field-option | create-field-option-response.json | - | - |
| review-threads | review-threads-response.json | - | - |
| resolve-thread | resolve-thread-response.json | - | - |

### graphql_create_project(owner_id, title)

Creates a GitHub Projects v2 project via GraphQL mutation.

**Parameters:**
- `owner_id`: The GraphQL ID of the owner
- `title`: The project title

**Returns:** JSON with `createProjectV2.projectV2` containing id, number, title, url

### graphql_lookup_owner(owner)

Looks up owner ID and type via GraphQL query.

**Parameters:**
- `owner`: The login name

**Returns:** JSON with `repositoryOwner` containing id and __typename

### graphql_lookup_project(owner, project_number)

Looks up project by owner and number via GraphQL query.

**Parameters:**
- `owner`: The login name
- `project_number`: The project number

**Returns:** JSON with `repositoryOwner.projectV2` containing id, number, title, url

### graphql_add_item(project_id, content_id)

Adds an issue or PR to a project via GraphQL mutation.

**Parameters:**
- `project_id`: The project GraphQL ID
- `content_id`: The issue/PR GraphQL ID

**Returns:** JSON with `addProjectV2ItemById.item.id`

### graphql_list_fields(project_id)

Lists single-select fields and options via GraphQL query.

**Parameters:**
- `project_id`: The project GraphQL ID

**Returns:** JSON with `node.fields.nodes` containing field id, name, and options array

### graphql_get_issue_project_item(owner, repo, issue_number)

Gets project items for an issue via GraphQL query.

**Parameters:**
- `owner`: Repository owner
- `repo`: Repository name
- `issue_number`: The issue number

**Returns:** JSON with `repository.issue` containing id and projectItems array

### graphql_update_field(project_id, item_id, field_id, option_id)

Updates a single-select field value via GraphQL mutation.

**Parameters:**
- `project_id`: The project GraphQL ID
- `item_id`: The project item GraphQL ID
- `field_id`: The field GraphQL ID
- `option_id`: The option GraphQL ID

**Returns:** JSON with `updateProjectV2ItemFieldValue.projectV2Item.id`

### graphql_create_field_option(field_id, option_name, option_color)

Creates a new single-select field option via GraphQL mutation.

**Parameters:**
- `field_id`: The field GraphQL ID
- `option_name`: The name for the new option
- `option_color`: The color (default: GRAY)

**Returns:** JSON with `createProjectV2FieldOption.projectV2SingleSelectFieldOption` containing id, name, color

### graphql_review_threads(owner, repo, pr_number)

Fetches PR review threads via GraphQL query.

**Parameters:**
- `owner`: Repository owner
- `repo`: Repository name
- `pr_number`: The PR number

**Returns:** JSON with `repository.pullRequest.reviewThreads` containing thread details and comments

### graphql_resolve_thread(thread_id)

Resolves a single PR review thread via GraphQL mutation.

**Parameters:**
- `thread_id`: The GraphQL ID of the review thread

**Returns:** JSON with `resolveReviewThread.thread` containing id and isResolved status

## Usage Examples

### Live API: Create and Configure Project

```bash
# Look up organization ID
owner_response=$(./scripts/gh-graphql.sh lookup-owner my-org)
owner_id=$(echo "$owner_response" | jq -r '.data.repositoryOwner.id')

# Create project
project_response=$(./scripts/gh-graphql.sh create-project "$owner_id" "My Project")
project_id=$(echo "$project_response" | jq -r '.data.createProjectV2.projectV2.id')

# List fields to find Status field
fields_response=$(./scripts/gh-graphql.sh list-fields "$project_id")
status_field_id=$(echo "$fields_response" | jq -r '.data.node.fields.nodes[] | select(.name=="Status") | .id')
```

### Fixture Mode: Testing Status Update

```bash
export AGENTIZE_GH_API=fixture

# Get issue's project item
item_response=$(./scripts/gh-graphql.sh get-issue-project-item owner repo 123)
item_id=$(echo "$item_response" | jq -r '.data.repository.issue.projectItems.nodes[0].id')
project_id=$(echo "$item_response" | jq -r '.data.repository.issue.projectItems.nodes[0].project.id')

# Get Status field and options
fields_response=$(./scripts/gh-graphql.sh list-fields "$project_id")
field_id=$(echo "$fields_response" | jq -r '.data.node.fields.nodes[] | select(.name=="Status") | .id')
option_id=$(echo "$fields_response" | jq -r '.data.node.fields.nodes[] | select(.name=="Status") | .options[] | select(.name=="In Progress") | .id')

# Update status
./scripts/gh-graphql.sh update-field "$project_id" "$item_id" "$field_id" "$option_id"
```

## Consumers

This script is used by:

- `src/cli/lol/project-lib.sh`: Project management operations (create, lookup, add-item, list-fields, update-field, create-field-option)
- `src/cli/wt/helpers.sh`: Worktree spawn status claiming (get-issue-project-item, update-field)
- `.claude-plugin/commands/resolve-review.md`: PR review thread resolution (review-threads, resolve-thread)
