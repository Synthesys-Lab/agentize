# Issue to Implementation Workflow

Complete development cycle from GitHub issue to pull request.

```mermaid
graph TD
    A[Github Issue created] --> B[Fork new branch from main]
    B --> C[Step 0: Update documentation]
    C --> D[Step 1: Create/update test cases]
    D --> E[Step 2: towards-next-milestone skill]
    E -->|more than 800 lines w/o finishing| F[Create milestone document]
    F --> G[User starts next session]
    G --> E
    E -->|finish all tests| H[Step 4: Code reviewer reviews quality]
    H --> I[Step 5: Create pull request]
    I --> J[User reviews and merges]

    style G fill:#ffcccc
    style J fill:#ffcccc
    style B fill:#ccddff
    style C fill:#ccddff
    style D fill:#ccddff
    style E fill:#ccddff
    style F fill:#ccddff
    style H fill:#ccddff
    style I fill:#ccddff
```

## Hands-Off Mode

Enable automated execution without manual permission prompts by setting `CLAUDE_HANDSOFF=true`. This auto-approves safe local operations (file edits, test runs, local commits) while maintaining safety boundaries for destructive or publish actions.

With hands-off mode enabled, the implementation workflow automatically continues through milestones up to the configured limit (default: 10 continuations per session). Once the limit is reached, manual resume is required:

```bash
User: Continue from the latest milestone
User: Resume implementation
```

See [Hands-Off Mode Documentation](../handsoff.md) for complete details on auto-continue limits and configuration.
