# File Movement and Renaming Safety Protocol

## Critical Requirements

When **moving** or **renaming** any existing file in the codebase, you MUST follow this protocol to prevent broken references and maintain system integrity.

**This protocol applies to:**
- Moving files to different directories
- Renaming files within the same directory
- Moving AND renaming files simultaneously

## Pre-Movement Analysis Steps

### Step 1: Search for All References
Before moving or renaming any file, use ripgrep to find ALL references to the file:

```bash
rg --hidden --glob '!externals/*' --glob '!.git/*' -n "filename\.ext"
```

**Key parameters:**
- `--hidden`: Include hidden files (like `.github/workflows/*.yml`)
- `--glob '!externals/*'`: Exclude externals directory
- `--glob '!.git/*'`: Exclude git internal files
- `-n`: Show line numbers for easier fixing
- Use the exact filename with escaped special characters (e.g., `\.` for periods)

**Example:**
```bash
rg --hidden --glob '!externals/*' --glob '!.git/*' -n "build-ci\.sh"
```

### Step 2: Read File Content Completely
Read the ENTIRE content of the file being moved to identify:
- Relative path dependencies
- Internal file references
- Scripts that assume specific working directories
- Import statements using relative paths

### Step 3: Update All References
Before moving or renaming the file:
1. Update ALL external references found in Step 1
2. Fix ANY internal relative path issues found in Step 2
3. Verify the file will work correctly from its new location

## File Operation Rules

### Single File Operations
- **ONLY move/rename ONE file at a time**
- Complete all reference updates for that file before the next operation
- Test that the moved/renamed file works correctly before proceeding

### Reference Update Order
1. **External references first**: Update all files that reference the target file
2. **Internal references second**: Update relative paths within the file itself
3. **Perform the operation last**: Only after all references are updated

### Operation-Specific Considerations

#### For File Moving (changing directory)
- Focus on path-based references
- Update relative path imports within the file
- Check for hardcoded directory assumptions

#### For File Renaming (changing filename)
- Focus on filename-based references
- Update import statements and function calls
- Search for exact filename matches (with and without extensions)
- Check for pattern-based references (e.g., `*.sh` patterns)

#### For Combined Move + Rename
- Apply both sets of considerations above
- Update references in two phases: path first, then filename

## Common Reference Types to Check

### External References
- GitHub Actions workflow files (`.github/workflows/*.yml`)
- Documentation files (README.md, *.md files)
- Other scripts that call or reference the file
- Build configuration files (Makefile, CMakeLists.txt)
- Claude rules (`.claude/rules/*.md`)

### Internal References
- Relative path imports (`../other-file`, `./same-dir-file`)
- Working directory assumptions (`cd $(dirname $0)`)
- Script directory calculations (`SCRIPT_DIR=$(dirname $0)`)
- File operations using relative paths
- Self-references within the file (logging, error messages)
- Hardcoded filenames in configuration or data files

## Verification Steps

After moving or renaming a file:
1. **Test functionality**: Run the moved file to ensure it works
2. **Test references**: Verify all files that reference it still work
3. **Run checks**: Execute `make check` to validate documentation consistency
4. **Test builds**: If applicable, test relevant build processes

## Example Workflows

### Example 1: Moving a File to Different Directory

Moving `utils/build-ci.sh` to `utils/build/build-ci.sh`:

```bash
# Step 1: Find all references
rg --hidden --glob '!externals/*' --glob '!.git/*' -n "build-ci\.sh"

# Step 2: Read file content (check for relative paths)
cat utils/build-ci.sh

# Step 3: Update all found references
# - Update .github/workflows/rhel9-build-and-test.yml
# - Update docs/PROJECT-CHARTER.md
# - Update any other referencing files

# Step 4: Move the file
mv utils/build-ci.sh utils/build/build-ci.sh

# Step 5: Test
./utils/build/build-ci.sh --help
```

### Example 2: Renaming a File in Same Directory

Renaming `utils/build-ci.sh` to `utils/build-all.sh`:

```bash
# Step 1: Find all references
rg --hidden --glob '!externals/*' --glob '!.git/*' -n "build-ci\.sh"
rg --hidden --glob '!externals/*' --glob '!.git/*' -n "build-ci"

# Step 2: Read file content (usually no internal changes needed for rename)
cat utils/build-ci.sh

# Step 3: Update all found references
# - Update .github/workflows/rhel9-build-and-test.yml
# - Update docs/PROJECT-CHARTER.md
# - Update any scripts that call "build-ci.sh"

# Step 4: Rename the file
mv utils/build-ci.sh utils/build-all.sh

# Step 5: Test
./utils/build-all.sh --help
```

### Example 3: Move + Rename Combined

Moving `utils/build-ci.sh` to `scripts/ci-build.sh`:

```bash
# Step 1: Find all references (both path and filename)
rg --hidden --glob '!externals/*' --glob '!.git/*' -n "utils/build-ci\.sh"
rg --hidden --glob '!externals/*' --glob '!.git/*' -n "build-ci\.sh"
rg --hidden --glob '!externals/*' --glob '!.git/*' -n "build-ci"

# Step 2: Read file content
cat utils/build-ci.sh

# Step 3: Update all found references (path + filename changes)
# - Update both directory and filename in all references
# - Check for any relative paths within the file itself

# Step 4: Move and rename
mv utils/build-ci.sh scripts/ci-build.sh

# Step 5: Test
./scripts/ci-build.sh --help
```

## Critical Notes

### General Rules
- **Never skip the search step**: Hidden files often contain critical references
- **Never move/rename multiple files simultaneously**: This makes debugging much harder
- **Always test after operations**: Ensure functionality is preserved
- **Update documentation**: Keep README.md files current with new locations/names

### Operation-Specific Notes

#### For Moving Files
- Pay special attention to relative path imports within the file
- Check scripts that use `$(dirname $0)` or similar directory calculations
- Update build system references (CMakeLists.txt, Makefiles)

#### For Renaming Files
- Search for both exact filename matches and stem matches (without extension)
- Check for wildcard patterns that might include the file (e.g., `*.py`, `test_*`)
- Update import statements in programming languages
- Look for references in comments and documentation

#### For Combined Operations
- Perform more comprehensive searches covering both aspects
- Consider updating references in two phases for clarity
- Test more thoroughly as both path and name have changed

### Special Cases
- **Executable scripts**: Update shebang paths if moved across system boundaries
- **Configuration files**: Check for hardcoded paths within the file
- **Test files**: Update test discovery patterns and imports
- **Documentation**: Update code examples and file listings

This protocol prevents broken builds, failed CI/CD pipelines, broken documentation links, and import failures.
