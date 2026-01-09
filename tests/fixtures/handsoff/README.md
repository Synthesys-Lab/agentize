# Handsoff Agent Test Fixtures

## Purpose

JSON fixtures providing mock tool use responses for testing the handsoff agent's automation workflows without requiring live Claude API calls.

## Contents

### Fixture Files

- `bash-add-plan-label.json` - Mock response for Bash tool adding [agentize:plan] label to issues
  - Simulates `gh issue edit --add-label "agentize:plan"` command execution
  - Used to test issue labeling automation

- `posttooluse-milestone.json` - Mock post-tool-use event for milestone creation
  - Simulates commit message skill invocation for milestone commits
  - Used to test milestone automation hooks

- `posttooluse-open-issue-auto.json` - Mock post-tool-use event for automatic issue creation
  - Simulates open-issue skill invocation during automated workflows
  - Used to test issue creation automation

- `posttooluse-open-pr.json` - Mock post-tool-use event for PR creation
  - Simulates open-pr skill invocation during automated workflows
  - Used to test PR creation automation

## Usage

These fixtures are consumed by handsoff agent tests (typically in `tests/e2e/`) to:

1. Mock GitHub CLI responses without requiring network access
2. Simulate tool use patterns for testing automation logic
3. Validate handsoff agent behavior in controlled scenarios

Example usage pattern in tests:
```bash
# Test reads fixture to simulate tool response
MOCK_RESPONSE=$(cat tests/fixtures/handsoff/bash-add-plan-label.json)
# Test validates handsoff agent processes the mock correctly
```

## Fixture Structure

Each JSON fixture follows the tool use response schema:
- Tool name (e.g., "Bash", "Skill")
- Parameters used in the tool invocation
- Simulated output or result
- Status/error information if applicable

## Maintenance

When updating handsoff agent automation:
- Add new fixtures for new tool use patterns
- Update existing fixtures if tool schemas change
- Ensure fixture names clearly describe the scenario being mocked

## Related Documentation

- [tests/e2e/test-external-consensus-issue-interface.sh](../../e2e/test-external-consensus-issue-interface.sh) - E2E test using these fixtures
- [.claude/skills/](../../../.claude/skills/) - Skill implementations tested by these fixtures
