# Issue to Implementation Workflow

Complete development cycle from GitHub issue to pull request.

```mermaid
graph TD
    A[Github Issue created] --> B[Fork new branch from main]
    B --> C[Step 5: Update documentation]
    C --> C2[Create docs commit with tag]
    C2 --> D[Step 6: Create/update test cases]
    D --> E[Step 8: towards-next-milestone skill]
    E -->|more than 800 lines w/o finishing| F[Create milestone document]
    F --> G[User starts next session]
    G --> E
    E -->|finish all tests| H[Code reviewer reviews quality]
    H --> I[Create pull request]
    I --> J[User reviews and merges]

    style G fill:#ffcccc
    style J fill:#ffcccc
    style B fill:#ccddff
    style C fill:#ccddff
    style C2 fill:#ccddff
    style D fill:#ccddff
    style E fill:#ccddff
    style F fill:#ccddff
    style H fill:#ccddff
    style I fill:#ccddff
```

## Documentation Commit Convention

The workflow creates a dedicated `[docs]` commit during Step 5, separate from test and implementation commits:

1. **Documentation files updated** - apply changes from "Documentation Planning" section
2. **Diff specifications followed** - if plan includes `--diff` previews, apply them directly
3. **Separate commit created** - `[docs]` tag enables easy tracking and revert if needed

This separation provides:
- Clear audit trail for documentation changes
- Ability to revert documentation independently from code
- Explicit tracking of documentation completeness

