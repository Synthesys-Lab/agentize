# lol CLI Options

This document provides detailed reference documentation for the `lol` command used to create an AI-powered SDK for your software development project.

**Quick Reference:** Use `lol --help` for a concise summary of options.

## Quick Reference

### Commands

```bash
lol init --name <name> --lang <lang> [--path <path>] [--source <path>] [--metadata-only]
lol update [--path <path>]
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

**Difference from `lol init`:**
- `lol update` only creates the `.claude/` directory and syncs AI configuration files
- It does NOT create language-specific project templates or scaffolding
- For full project setup with language templates, use `lol init` instead

**Example:**
```bash
lol update                      # From project root or subdirectory
lol update --path /path/to/project
```

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
