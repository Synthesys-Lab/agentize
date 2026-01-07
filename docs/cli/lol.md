# lol CLI Options

This document provides detailed reference documentation for the `lol` command used to create an AI-powered SDK for your software development project.

**Quick Reference:** Use `lol --help` for a concise summary of options.

## Quick Reference

### Commands

```bash
lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]
lol update [--path <path>]
lol upgrade
lol --version
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
- `--version` - Display version information

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
- Preserves existing `.agentize.yaml` fields without overwriting
- Records `agentize.commit` (current agentize installation commit hash) in `.agentize.yaml` when git is available
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

### `lol --version`

Displays version information for both the agentize installation and the current project's last update (if available).

**Behavior:**

- Prints the agentize installation commit hash (from `AGENTIZE_HOME` git repository)
- Prints the project's last update commit hash (from `.agentize.yaml` `agentize.commit` field, if present)
- Displays "Not a git repository" for installation if `AGENTIZE_HOME` is not a git repo
- Displays "Not set" for project update if `.agentize.yaml` is missing or `agentize.commit` is not set

**Output format:**
```
Installation: <commit-hash>
Last update:  <commit-hash>
```

**Example:**
```bash
$ lol --version
Installation: e3eab9a1234567890abcdef1234567890abcdef
Last update:  a1b2c3d4567890abcdef1234567890abcdef123
```

### `lol upgrade`

Upgrades your agentize installation by pulling the latest changes from the remote repository.

**No flags required.**

**Behavior:**

- Validates `AGENTIZE_HOME` points to a valid git worktree
- Checks for uncommitted changes in the worktree
  - If dirty, prints guidance to commit/stash and exits
- Resolves the default branch from `origin/HEAD` (supports both `main` and `master`)
  - Falls back to `main` if `origin/HEAD` is not available
- Runs `git pull --rebase origin <branch>` in the `AGENTIZE_HOME` worktree
- On rebase failure, prints recovery hint (`git rebase --abort`) and retry guidance
- On success, prints shell reload instructions:
  - `exec $SHELL` - Clean shell restart (recommended)
  - Re-source `setup.sh` - In-place reload (alternative)

**Error handling:**

*Worktree validation failure:*
```
Error: AGENTIZE_HOME is not a valid git worktree.
```

*Uncommitted changes detected:*
```
Warning: Uncommitted changes detected in AGENTIZE_HOME.

Please commit or stash your changes before upgrading:
  git add .
  git commit -m "..."
OR
  git stash
```

*Rebase conflict:*
```
Error: git pull --rebase failed.

To resolve:
1. Fix conflicts in the files listed above
2. Stage resolved files: git add <file>
3. Continue: git -C $AGENTIZE_HOME rebase --continue
OR abort: git -C $AGENTIZE_HOME rebase --abort

Then retry: lol upgrade
```

**Example:**
```bash
lol upgrade
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
- Closes linked issues when associated PRs are merged

**Automatic configuration:**
- Checks if "Stage" field exists in your project
- Creates the "Stage" field (proposed, accepted) if it doesn't exist
- Auto-fills `STAGE_FIELD_ID` in the generated workflow

Configuration required: PAT with project permissions. Stage field is configured automatically if you have project access.

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

## Shell Completion (zsh)

The `lol` command provides tab-completion support for zsh users. After running `make setup` and sourcing `setup.sh`, completions are automatically enabled.

**Features:**
- Subcommand completion (`lol <TAB>` shows: init, update, upgrade, version, project)
- Flag completion for `init` (`--name`, `--lang`, `--path`, `--source`, `--metadata-only`)
- Flag completion for `update` (`--path`)
- Flag completion for `project` (`--create`, `--associate`, `--automation`)
- Value completion for `--lang` (c, cxx, python)
- Path completion for path-related flags

**Setup:**
1. Run `make setup` to generate `setup.sh`
2. Source `setup.sh` in your shell: `source setup.sh`
3. Tab-completion will be available for `lol` commands

**Note:** Completion setup only affects zsh users. Bash users can continue using `lol` without any changes.

## Completion Helper Interface

The `lol` command includes a shell-agnostic completion helper for use by completion systems:

```bash
lol --complete <topic>
```

**Topics:**
- `commands` - List available subcommands (init, update, upgrade, version, project)
- `init-flags` - List flags for `lol init` (--name, --lang, --path, --source, --metadata-only)
- `update-flags` - List flags for `lol update` (--path)
- `project-modes` - List project mode flags (--create, --associate, --automation)
- `project-create-flags` - List flags for `lol project --create` (--org, --title)
- `project-automation-flags` - List flags for `lol project --automation` (--write)
- `lang-values` - List supported language values (c, cxx, python)

**Output format:** Newline-delimited tokens, no descriptions.

**Example:**
```bash
$ lol --complete commands
init
update
upgrade
version
project

$ lol --complete init-flags
--name
--lang
--path
--source
--metadata-only

$ lol --complete lang-values
c
cxx
python
```

This helper is used by the zsh completion system and can be used by other shells in the future.

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
