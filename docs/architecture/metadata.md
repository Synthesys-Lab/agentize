# Project Metadata File (.agentize.yaml)

The `.agentize.yaml` file provides canonical project configuration for agentize-based projects.

## Configuration Files Overview

Agentize uses two configuration files with distinct purposes:

| File | Purpose | Committed? |
|------|---------|------------|
| `.agentize.yaml` | Project metadata (org, project ID, language) | Yes |
| `.agentize.local.yaml` | Runtime settings (credentials, worker config, models) | No |

**Separation rationale:**
- `.agentize.yaml` contains project-level configuration that should be shared across all developers
- `.agentize.local.yaml` contains deployment-specific settings (secrets, machine-specific tuning) that vary per environment

For runtime configuration details, see [Server Runtime Configuration](../feat/server.md#runtime-configuration).

## Location

The metadata file is located at the project root:
- Standard layout: `<project-root>/.agentize.yaml`
- Worktree layout: `<repo-root>/trees/main/.agentize.yaml`

The `wt` command automatically searches both locations.

## Schema

```yaml
project:
  name: project-name           # Project identifier
  lang: python|bash|c|cxx      # Primary programming language
  source: src                  # Source code directory (optional)
  org: organization-name       # GitHub organization (optional, for Projects v2)
  id: 3                        # GitHub project number (optional, for Projects v2)

git:
  remote_url: https://github.com/org/repo  # Git remote URL (optional)
  default_branch: main         # Default branch (main, master, trunk, etc.)

agentize:
  commit: abc123...            # Agentize commit hash from last update (optional)

worktree:
  trees_dir: trees            # Worktree directory (optional, defaults to "trees")

pre_commit:
  enabled: true               # Enable pre-commit hook installation (optional, defaults to true)
```

## Fields

### project.name (required)
Project identifier used in templates and documentation.

**Example:** `agentize`, `my-project`

### project.lang (required)
Primary programming language of the project.

**Supported values:**
- `python` - Python projects
- `bash` - Bash script projects
- `c` - C language projects
- `cxx` - C++ projects

**Usage:** Determines language-specific defaults and tooling behavior.

### project.source (optional)
Path to source code directory relative to project root.

**Default:** Language-specific defaults (`src` for Python, `scripts` for Bash)

**Example:** `lib`, `src`, `custom/path`

### git.remote_url (optional)
Git remote repository URL.

**Example:** `https://github.com/synthesys-lab/agentize`

**Usage:** Documentation and tooling reference. The server uses this to generate GitHub issue links in worker assignment Telegram notifications.

### git.default_branch (optional but recommended)
Default branch name for creating worktrees.

**Default:** Auto-detected (tries `main`, then `master`)

**Example:** `main`, `master`, `trunk`, `develop`

**Why specify:** Required for non-standard branch names (e.g., `trunk`). When absent, `wt` falls back to auto-detection and shows a hint.

### worktree.trees_dir (optional)
Directory where worktrees are created.

**Default:** `trees`

**Example:** `worktrees`, `branches`, `trees`

**Usage:** Allows customizing worktree organization.

### project.org (optional)
GitHub owner (organization or personal user login) for Projects v2 integration.

**Example:** `Synthesys-Lab`, `my-org`, `my-username`

**Usage:** Set by `lol project --create` or `lol project --associate` to store the owner associated with the GitHub Projects v2 board. This can be an organization login or a personal user login, enabling Projects v2 integration for both organization-owned and user-owned repositories.

### project.id (optional)
GitHub Projects v2 board number (the numeric ID visible in the project URL).

**Example:** `3`, `42`

**Usage:** Set by `lol project --create` or `lol project --associate` to store the project number. This is the project number shown in URLs like `https://github.com/orgs/my-org/projects/3` (for organizations) or `https://github.com/users/my-username/projects/1` (for personal accounts), NOT the GraphQL node_id.

**Note:** The `project.org` and `project.id` fields work together to uniquely identify a GitHub Projects v2 board. The URL path (`orgs/` vs `users/`) is determined dynamically based on the owner type.

### agentize.commit (optional)
Records the agentize installation commit hash.

**Example:** `e3eab9a1234567890abcdef1234567890abcdef`

**Usage:** Records which agentize version is being used. This enables version tracking via `lol version` for troubleshooting and compatibility checks.

**Note:** Only recorded when `AGENTIZE_HOME` is a valid git repository. If git is not available or `AGENTIZE_HOME` is not a git repo, this field is omitted without causing errors.

### pre_commit.enabled (optional)
Controls automatic installation of the pre-commit hook during SDK and worktree initialization.

**Default:** `true` (hook is installed when missing)

**Example:** `true`, `false`

**Usage:** Set to `false` to prevent automatic hook installation. When `true` or unset, `wt init` and `wt spawn` will install `scripts/pre-commit` into `.git/hooks/pre-commit` if the hook script exists and no custom hook is already present.

**Note:** Hook installation is also skipped when Git hooks are globally disabled via `core.hooksPath` (e.g., `core.hooksPath=/dev/null`). This ensures the commands respect user intent to disable hooks system-wide.

## Creation

### Manual Creation

Create `.agentize.yaml` manually:

```bash
cat > .agentize.yaml <<EOF
project:
  name: my-project
  lang: python
  source: src
git:
  default_branch: main
EOF
```

This enables worktree operations (`wt` command) and project management features.

## Usage

### Worktree Configuration

The `wt` command reads metadata for worktree operations:

```bash
# Uses git.default_branch from .agentize.yaml
wt spawn 42

# Uses worktree.trees_dir from .agentize.yaml
wt list
```

**Fallback behavior:** When `.agentize.yaml` is missing, `wt` falls back to:
- Auto-detect `main` or `master` branch
- Use `trees` directory
- Display hint to create `.agentize.yaml` manually

## Example: Agentize Project

```yaml
project:
  name: agentize
  lang: bash
  source: scripts
  org: Synthesys-Lab
  id: 3
git:
  remote_url: https://github.com/synthesys-lab/agentize
  default_branch: main
agentize:
  commit: e3eab9a1234567890abcdef1234567890abcdef
worktree:
  trees_dir: trees
```

## Example: Non-Standard Branch

For projects using `trunk` instead of `main`:

```yaml
project:
  name: my-project
  lang: python
git:
  default_branch: trunk
```

This enables `wt spawn` to correctly fork from `trunk`.

## Preservation

**Editing:** Safe to edit manually. The file uses standard YAML format. User modifications are safe.

## Notes

- Minimal YAML parser used (no external dependencies)
- Supports only the documented fields
- Comments allowed (lines starting with `#`)
- Whitespace-insensitive (standard YAML indentation)
