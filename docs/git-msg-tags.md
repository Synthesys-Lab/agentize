# Git Message Tags

This document defines the tags to be used in git commit messages.

## Commit Tags

- `feat`: A new feature has been added.
- `sdk`: The SDK template to be modified or created.
- `cli`: The command line interface related changes.
- `bugfix`: A bug has been fixed.
- `docs`: Documentation has been updated or added.
- `test`: Test cases as well as test related infras have been added or modified.
  - DO NOT use this tag when `bugfix`, `sdk`, or `feat` is also present.
  - Use this tag only when solely modifying test cases.
- `refactor`: Code has been refactored without changing its functionality.
- `chore`: Routine tasks such as code formatting, dependency updates, etc.
- `agent.<sub-tag>`: Changes related to AI agent configuration or behavior.
  - `.skill`: Modifying existing skills or adding new skills.
  - `.command`: Changes to slash commands.
  - `.settings`: Changes to agent settings or configurations.
  - `.workflow`: Changes to agent-based workflows or processes.
- `review`: If this code change is driven by a code review comment.
  - Use this tag in addition before any other tags.
  - This typically cannot be a standalone tag.

## Issue Tags

- `plan`: A plan that is created by `/plan-an-issue` (simple) or `/ultra-planner` (complicated) commands.
  - `draft`: A plan is a draft (not reviewed and approved by a human yet).
- `discussion`: An issue is created from a summary of a disccussion.
- `roadmap`: An issue is created from `/roadmapper` command by feeding a `discussion` issue.
