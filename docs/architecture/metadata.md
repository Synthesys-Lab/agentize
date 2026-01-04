# Project Metadata File (.agentize.yaml)

The `.agentize.yaml` file provides canonical project configuration for agentize-based projects.

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

**Usage:** Determines which SDK templates are used during `lol init`.

### project.source (optional)
Path to source code directory relative to project root.

**Default:** Language-specific defaults (`src` for Python, `scripts` for Bash)

**Example:** `lib`, `src`, `custom/path`

### git.remote_url (optional)
Git remote repository URL.

**Example:** `https://github.com/synthesys-lab/agentize`

**Usage:** Documentation and tooling reference.

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
GitHub organization name for Projects v2 integration.

**Example:** `Synthesys-Lab`, `my-org`

**Usage:** Set by `lol project --create` or `lol project --associate` to store the organization associated with the GitHub Projects v2 board.

### project.id (optional)
GitHub Projects v2 board number (the numeric ID visible in the project URL).

**Example:** `3`, `42`

**Usage:** Set by `lol project --create` or `lol project --associate` to store the project number. This is the project number shown in URLs like `https://github.com/orgs/my-org/projects/3`, NOT the GraphQL node_id.

**Note:** The `project.org` and `project.id` fields work together to uniquely identify a GitHub Projects v2 board.

### pre_commit.enabled (optional)
Controls automatic installation of the pre-commit hook during SDK and worktree initialization.

**Default:** `true` (hook is installed when missing)

**Example:** `true`, `false`

**Usage:** Set to `false` to prevent automatic hook installation. When `true` or unset, `lol init`, `lol update`, `wt init`, and `wt spawn` will install `scripts/pre-commit` into `.git/hooks/pre-commit` if the hook script exists and no custom hook is already present.

**Note:** Hook installation is also skipped when Git hooks are globally disabled via `core.hooksPath` (e.g., `core.hooksPath=/dev/null`). This ensures the commands respect user intent to disable hooks system-wide.

## Creation

### Automatic Creation

The `.agentize.yaml` file is automatically created by:

**`lol init`:**
```bash
lol init --name my-project --lang python
```
Creates `.agentize.yaml` with provided name, language, and detected git branch.

**`lol init --metadata-only`:**
```bash
lol init --name my-project --lang python --metadata-only
```
Creates only `.agentize.yaml` without SDK templates or `.claude/` configuration. This is useful for adding metadata to existing projects.

**`lol update`:**
```bash
lol update
```
Creates `.agentize.yaml` if missing, using:
- Project name from directory basename
- Language from `detect-lang.sh` detection
- Git branch from repository detection

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

### Metadata-Only Mode

For existing projects that need only `.agentize.yaml` without full SDK initialization:

```bash
# Add metadata to existing project
lol init --name my-project --lang python --metadata-only

# Allows non-empty directories
lol init --name existing-app --lang cxx --path /path/to/existing-app --metadata-only
```

This creates only the metadata file, enabling worktree operations (`wt` command) without SDK template overhead.

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
- Display hint: "Run 'lol init' or 'lol update' to create project metadata"

### Project Initialization

The `lol init` command uses metadata to set up new projects:

```bash
lol init --name agentize --lang bash --source scripts
```

Creates `.agentize.yaml` with these values, enabling consistent project setup.

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

**`lol update` preserves existing `.agentize.yaml`:**
- Does not overwrite user customizations
- Only creates file if missing
- User modifications are safe

**Editing:** Safe to edit manually. The file uses standard YAML format.

## Migration

For existing projects without `.agentize.yaml`:

1. Run `lol update` to auto-generate
2. Review and customize generated file
3. Commit to repository: `git add .agentize.yaml && git commit`

## Notes

- Minimal YAML parser used (no external dependencies)
- Supports only the documented fields
- Comments allowed (lines starting with `#`)
- Whitespace-insensitive (standard YAML indentation)
