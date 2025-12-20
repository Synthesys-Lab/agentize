---
paths: ".github/workflows/*.yml, .github/workflows/*.yaml, .github/*.yml, .github/*.yaml"
---

# GitHub Workflows README Synchronization

## CRITICAL REQUIREMENT: README.md Update

Whenever GitHub Actions workflow files are modified in:
- `.github/workflows/` directory (any `.yml` or `.yaml` files)
- `.github/` root directory (any `.yml` or `.yaml` files)

You **MUST** update [.github/workflows/README.md](../../.github/workflows/README.md) to reflect the changes.

## What requires README updates:

### Workflow Structure Changes
- Adding new workflows
- Removing existing workflows
- Modifying workflow dependencies
- Changing workflow names or purposes

### Logic Changes
- Modifying build decision logic
- Changing file extension whitelists
- Updating conditional execution logic
- Altering workflow triggers

### Architecture Changes
- Changes to reusable workflow patterns
- Modifications to workflow dependencies
- Updates to job relationships
- Changes in workflow orchestration

## Required README.md sections to maintain:

### 1. Workflow Architecture Diagram
- Keep the Mermaid diagram updated with current workflow relationships
- Update decision paths when logic changes
- Add new workflows to the visual architecture

### 2. Current Workflows Section
- Update workflow descriptions when purposes change
- Modify environment details when build contexts change
- Update skip logic documentation when conditions change

### 3. Configuration Management
- Update file extension whitelist documentation when changed
- Modify build logic descriptions when updated
- Update dependency information when workflows are added/removed

### 4. Key Features Section
- Update feature descriptions when capabilities change
- Modify logic explanations when decision trees change
- Update resource efficiency details when optimization changes

## Update Process:

1. **Immediate Update**: Update README.md in the same commit as workflow changes
2. **Comprehensive Review**: Ensure all affected sections are updated
3. **Accuracy Verification**: Verify technical details match actual implementation
4. **Clear Documentation**: Maintain clear, accurate descriptions of current state

## Examples:

### Adding New Workflow
When adding `security-scan.yml`:
- Add to architecture diagram
- Create new section in "Current Workflows"
- Update workflow dependencies section
- Modify any affected decision logic documentation

### Modifying File Whitelist
When adding new file extensions to `whether-e2e-build-test-clean.yml`:
- Update whitelist documentation in README.md
- Ensure consistency between implementation and documentation
- Update examples if needed

### Changing Build Logic
When modifying skip conditions:
- Update architecture diagram decision paths
- Modify logic descriptions in relevant sections
- Update feature descriptions if capabilities change

## Documentation Quality Standards:

- **Accuracy**: Documentation must match current implementation
- **Completeness**: All workflows must be documented
- **Clarity**: Technical details should be clear and actionable
- **Currency**: Keep "Last Updated" timestamp current

## Integration with Project Rules:

This rule works in conjunction with:
- [documentation-guidelines.md](./documentation-guidelines.md) for documentation quality and structure maintenance
- [language.md](./language.md) for English language requirements

**Remember**: CI/CD workflows are critical infrastructure. Documentation must be maintained as carefully as the code itself to ensure team understanding and maintainability.
