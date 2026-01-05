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

### lookup-project-response.json
Mock response for looking up an existing project. Used when testing `lol project --associate`.

**Query:**
```graphql
query {
  organization(login: "test-org") {
    projectV2(number: 3) {
      id
      number
      title
      url
    }
  }
}
```

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

## Usage in Tests

Tests should set `AGENTIZE_GH_API` environment variable to use fixtures instead of live API:

```bash
export AGENTIZE_GH_API=fixture
```

The `scripts/gh-graphql.sh` wrapper checks this variable and returns fixture data when set. Additionally, fixture mode bypasses the `gh auth status` preflight check in `scripts/agentize-project.sh`, allowing tests to run in CI environments without GitHub authentication.
