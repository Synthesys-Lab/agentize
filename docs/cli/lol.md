# lol CLI Options

This document provides detailed reference documentation for the `lol` command used to create an AI-powered SDK for your software development project.

**Quick Reference:** Use `lol --help` for a concise summary of options.

## Quick Reference

### Commands

```bash
lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]
lol update [--path <path>]
lol project --create [--org <org>] [--title <title>]
lol project --associate <org>/<id>
lol project --automation [--write <path>]
```

### Flags

- `--name <name>` - Project name (required for init)
- `--lang <lang>` - Programming language: c, cxx, python (required for init)
- `--path <path>` - Project path (optional, defaults to current directory)
- `--source <path>` - Source code path relative to project root (optional)
- `--metadata-only` - Create only .agentize.yaml without SDK templates (optional, init only)

## Commands

### `lol init`

Initializes an SDK structure in the specified project path and copies necessary template files.

**Required flags:**
- `--name` - Project name
- `--lang` - Programming language (c, cxx, or python)

**Optional flags:**
- `--path` - Project path (defaults to current directory)
- `--source` - Source code path relative to project root
- `--metadata-only` - Create only `.agentize.yaml` without copying SDK templates or `.claude/` configuration

**Behavior:**

*Standard mode (without `--metadata-only`):*
- If the project path exists and is empty, copies SDK template files
- If the project path exists and is not empty, aborts with error
- If the project path does not exist, creates it and copies template files
- Creates `.agentize.yaml` with project metadata including:
  - `project.name`, `project.lang`, `project.source`
  - `git.default_branch` (if git repository is initialized)
- Installs pre-commit hook from `scripts/pre-commit` if available and `.git` directory exists (unless `pre_commit.enabled: false` in metadata)

*Metadata-only mode (with `--metadata-only`):*
- Creates only `.agentize.yaml` file
- Does NOT copy SDK template files or `.claude/` directory
- Allows non-empty directories (useful for adding metadata to existing projects)
- Preserves existing `.agentize.yaml` if present
- Still requires `--name` and `--lang` flags

**Examples:**

Standard initialization:
```bash
lol init --name my-project --lang python --path /path/to/project
```

Metadata-only mode (for existing projects):
```bash
lol init --name my-project --lang python --path /path/to/existing-project --metadata-only
```

### `lol update`

Updates the AI-related rules and files in an existing SDK structure without affecting user's custom rules. If `.claude/` directory is missing, it will be created automatically.

**Optional flags:**
- `--path` - Project path (defaults to searching for nearest `.claude/` directory)

**Behavior:**
- Searches for nearest `.claude/` directory by traversing parent directories
- If `--path` provided, uses that path directly
- If no `.claude/` directory found, creates it in the target path and proceeds with update
- Creates `.claude/` backup before updates if the directory existed previously
- Syncs AI configuration files and documentation from templates
- Creates `.agentize.yaml` if missing, using best-effort detection for:
  - `project.name` (from directory basename)
  - `project.lang` (via `detect-lang.sh`)
  - `git.default_branch` (if git repository exists)
- Preserves existing `.agentize.yaml` without overwriting
- Installs pre-commit hook from `scripts/pre-commit` if available and `.git` directory exists (unless `pre_commit.enabled: false` in metadata)
- Prints conditional post-update hints based on available resources:
  - `make test` (if Makefile has `test:` target)
  - `make setup` (if Makefile has `setup:` target)
  - Documentation link (if `docs/architecture/architecture.md` exists)

**Difference from `lol init`:**
- `lol update` only creates the `.claude/` directory and syncs AI configuration files
- It does NOT create language-specific project templates or scaffolding
- For full project setup with language templates, use `lol init` instead

**Example:**
```bash
lol update                      # From project root or subdirectory
lol update --path /path/to/project
```

### `lol project`

Integrates your repository with GitHub Projects v2. This command creates or associates a project board, persists the association in `.agentize.yaml`, and can generate automation templates.

**Subcommands:**

**Create a new project:**
```bash
lol project --create [--org <org>] [--title <title>]
```

Creates a new GitHub Projects v2 board and associates it with the repository.

- `--org` - GitHub organization (optional, defaults to repository owner)
- `--title` - Project title (optional, defaults to repository name)

**Associate an existing project:**
```bash
lol project --associate <org>/<id>
```

Associates an existing GitHub Projects v2 board with the repository.

- `<org>/<id>` - Organization and project number (e.g., `Synthesys-Lab/3`)

**Generate automation template:**
```bash
lol project --automation [--write <path>]
```

Prints or writes a GitHub Actions workflow template for project automation with lifecycle management.

The generated template:
- Automatically adds new issues and PRs to the project board
- Sets Stage field to "proposed" for newly opened issues
- Updates linked issues to Stage "done" when associated PRs are merged

Configuration required: PAT with project permissions, field/option IDs for Stage updates.

- `--write` - Write template to file (optional, defaults to stdout)

**Behavior:**

- All commands update `.agentize.yaml` with project metadata:
  - `project.org` - GitHub organization
  - `project.id` - Project number (not node_id)
- Requires `gh` CLI to be installed and authenticated
- `--create` and `--associate` validate project access via GraphQL
- Automation setup is manual (see generated template or docs)

**Examples:**

Create a new project:
```bash
lol project --create --org Synthesys-Lab --title "Agentize Development"
```

Associate existing project:
```bash
lol project --associate Synthesys-Lab/3
```

Generate and save automation workflow:
```bash
lol project --automation --write .github/workflows/add-to-project.yml
```

**Related documentation:**
- [GitHub Projects automation guide](../workflows/github-projects-automation.md)
- [Metadata schema](../architecture/metadata.md)
- [Project management](../architecture/project.md)

## Flag Details

### `--name <name>`

Specifies the name of your project. This name will be used in various parts of the generated SDK.

**Required for:** `init`

### `--lang <lang>`

Specifies the programming language of your project.

**Supported values:**
- `c` - C language
- `cxx` - C++ language
- `python` - Python language

**Required for:** `init`

**Note:** More languages (Java, Rust, Go, JavaScript) will be added in future versions.

### `--path <path>`

Specifies the file system path where the SDK will be created or updated. Ensure you have write permissions.

**Optional for:** `init`, `update`
**Default:** Current directory for `init`, nearest `.claude/` directory for `update` (falls back to current directory if none found)

### `--source <path>`

Specifies the path to the source code of your project, relative to the project root.

**Optional for:** `init`
**Default:** For C/C++ projects, both `src/` and `include/` directories are used

**Example:** LLVM uses `lib/` directory for source code:
```bash
lol init --name llvm-project --lang cxx --path /path/to/llvm --source lib
```

### `--metadata-only`

Creates only the `.agentize.yaml` metadata file without copying SDK templates or `.claude/` configuration. This is useful for adding agentize metadata to existing projects without full SDK initialization overhead.

**Optional for:** `init`

**Use cases:**
- Adding metadata to existing projects for worktree operations (`wt` command)
- Projects that already have custom `.claude/` configurations
- Lightweight metadata creation without template files

**Example:**
```bash
lol init --name existing-project --lang python --metadata-only
```
