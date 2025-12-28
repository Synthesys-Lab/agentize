# lol CLI Options

This document provides detailed reference documentation for the `lol` command used to create an AI-powered SDK for your software development project.

**Quick Reference:** Use `lol --help` for a concise summary of options.

## Quick Reference

### Commands

```bash
lol init --name <name> --lang <lang> [--path <path>] [--source <path>]
lol update [--path <path>]
```

### Flags

- `--name <name>` - Project name (required for init)
- `--lang <lang>` - Programming language: c, cxx, python (required for init)
- `--path <path>` - Project path (optional, defaults to current directory)
- `--source <path>` - Source code path relative to project root (optional)

## Commands

### `lol init`

Initializes an SDK structure in the specified project path and copies necessary template files.

**Required flags:**
- `--name` - Project name
- `--lang` - Programming language (c, cxx, or python)

**Optional flags:**
- `--path` - Project path (defaults to current directory)
- `--source` - Source code path relative to project root

**Behavior:**
- If the project path exists and is empty, copies SDK template files
- If the project path exists and is not empty, aborts with error
- If the project path does not exist, creates it and copies template files

**Example:**
```bash
lol init --name my-project --lang python --path /path/to/project
```

### `lol update`

Updates the AI-related rules and files in an existing SDK structure without affecting user's custom rules.

**Optional flags:**
- `--path` - Project path (defaults to searching for nearest `.claude/` directory)

**Behavior:**
- Searches for nearest `.claude/` directory by traversing parent directories
- If `--path` provided, uses that path directly
- Aborts if no valid SDK structure found

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
**Default:** Current directory for `init`, nearest `.claude/` directory for `update`

### `--source <path>`

Specifies the path to the source code of your project, relative to the project root.

**Optional for:** `init`
**Default:** For C/C++ projects, both `src/` and `include/` directories are used

**Example:** LLVM uses `lib/` directory for source code:
```bash
lol init --name llvm-project --lang cxx --path /path/to/llvm --source lib
```
