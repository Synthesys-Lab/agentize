# GitHub Projects v2 GraphQL Fixtures

This directory contains mock GraphQL responses for testing `lol project` command without making live API calls.

## Files

### create-project-response.json
Mock response for `createProjectV2` mutation. Used when testing `lol project --create`.

**Query:**
```graphql
mutation {
  createProjectV2(input: {ownerId: "...", title: "..."}) {
    projectV2 {
      id
      number
      title
      url
    }
  }
}
```

### lookup-owner-response.json
Mock response for looking up an organization owner. Used to determine owner type before project lookup.

**Query:**
```graphql
query($owner: String!) {
  repositoryOwner(login: $owner) {
    id
    __typename
  }
}
```

### lookup-owner-user-response.json
Mock response for looking up a user owner. Used when `AGENTIZE_GH_OWNER_TYPE=user`.

### lookup-project-response.json
Mock response for looking up an existing organization project. Used when testing `lol project --associate`.

**Query:**
```graphql
query($owner: String!, $number: Int!) {
  repositoryOwner(login: $owner) {
    ... on Organization { projectV2(number: $number) { id number title url } }
    ... on User { projectV2(number: $number) { id number title url } }
  }
}
```

### lookup-project-user-response.json
Mock response for looking up a user project. Used when `AGENTIZE_GH_OWNER_TYPE=user`.

### create-project-user-response.json
Mock response for creating a user project. Used when `AGENTIZE_GH_OWNER_TYPE=user`.

### add-item-response.json
Mock response for adding an issue or PR to a project. Used when testing optional `--add` functionality.

**Query:**
```graphql
mutation {
  addProjectV2ItemById(input: {projectId: "...", contentId: "..."}) {
    item {
      id
    }
  }
}
```

### get-issue-project-item-response.json
Mock response for looking up an issue's project items. Used when testing `wt spawn` status claim functionality.

**Query:**
```graphql
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    issue(number:$number) {
      id
      projectItems(first: 20) {
        nodes {
          id
          project { id }
        }
      }
    }
  }
}
```

### update-field-response.json
Mock response for updating a project field value. Used when testing `wt spawn` status claim functionality.

**Query:**
```graphql
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId, fieldId: $fieldId,
    value: { singleSelectOptionId: $optionId }
  }) {
    projectV2Item { id }
  }
}
```

## Usage in Tests

Tests should set `AGENTIZE_GH_API` environment variable to use fixtures instead of live API:

```bash
export AGENTIZE_GH_API=fixture
```

The `scripts/gh-graphql.sh` wrapper checks this variable and returns fixture data when set. Additionally, fixture mode bypasses the `gh auth status` preflight check in `scripts/agentize-project.sh`, allowing tests to run in CI environments without GitHub authentication.

## Owner Type Selection

By default, fixtures return organization-style responses. To test user-owned projects, set `AGENTIZE_GH_OWNER_TYPE`:

```bash
export AGENTIZE_GH_OWNER_TYPE=user
```

This selects user-specific fixtures (`lookup-owner-user-response.json`, `lookup-project-user-response.json`, `create-project-user-response.json`) which return URLs with `/users/` path instead of `/orgs/`.
