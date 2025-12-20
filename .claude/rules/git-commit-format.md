# Git Commit Message Format

## Required Format

### Standard Format

All commit messages must follow this structure:
```
[tag] Brief description of changes

[filetype] /path/to/file : Reason for modifying this file
[filetype] /path/to/file : Reason for modifying this file

Detailed explanation of the commit content (optional).
Each line should not exceed 75 characters.
Maximum 10 lines for the detailed explanation.
```

### Multi-Tag Format (for PRs/Issue-Related Commits)

Commits related to issues/PRs can use multiple tags matching the issue/PR title format:
```
[Component][SubArea][Issue #XX] Brief description

[filetype] /path/to/file : Reason for modifying this file
```

This format is especially useful for squash-merged PR commits where the PR title becomes the commit message.

### Simplified Format

For certain types of commits, you can use a simplified format with only the subject line:
```
[tag] Brief description of changes
```

Or with multiple tags:
```
[Component][SubArea] Brief description
```

**Simplified format is allowed when ANY of these conditions are met:**

1. **Submodule-related changes**: Either of the following scenarios:
   - `.gitmodules` is modified (submodule add/remove) AND all other changes are to submodule paths
   - Only submodule paths are modified (submodule version updates, no `.gitmodules` changes)
2. **Small changes**: Changes affect ≤2 files AND total line changes <10 lines

**Important Notes:**
- MUST NOT contain AI Authorship (No Claude Code, Gemini CLI, Grok, GPT)
- Only commit those staged changes. If you find that some changed and staged files should be in different commits, then use `git commit <file1> <file2> -m "your message"`
- The first line (subject) is mandatory in all formats
- For standard format: a blank line must follow the subject line
- File modifications section is optional but recommended for multi-file changes
- A blank line must precede the detailed explanation if present
- Detailed explanation is optional but helpful for complex changes
- The git hook will automatically detect if your changes qualify for simplified format

## Component Tags Reference

For the complete list of component tags specific to this project, see:

**`.claude/git-tags.md`** - Project-specific component tag definitions

You should review `.claude/git-tags.md` to understand the component structure and available tags for this project. These custom tags can be used in combination with the general development tags listed below.

## Commit Workflow

When asked to perform git operations (add/commit/push), follow this workflow:

1. **Analyze Changes First**:
   - Use `git diff` to examine all modifications
   - Review modified files and their content
   - Understand the purpose of each change

2. **Group Related Changes**:
   - Identify changes that serve the same purpose
   - Group similar or related modifications together
   - Each logical change should be a separate commit

3. **Create Multiple Commits**:
   - Use `git add` to stage related files for each logical change
   - Create a commit with a brief but compliant message
   - Repeat "git add" and "git commit" for each group of changes
   - Each commit message should be concise but follow all format requirements

4. **Maintain Commit Atomicity**:
   - Never mix unrelated changes in a single commit
   - Each commit should represent one logical change
   - If changes serve different purposes, they must be separate commits

5. **Push When Complete**:
   - After all commits are created, perform `git push` if requested
   - Only push once at the end, not after each commit

**Example Workflow**:
```bash
# 1. Check what has changed
git diff
git status

# 2. First logical change: bug fix
git add lib/Engine/Memory.cpp tests/test_memory.cpp
git commit -m "[fix] Resolve memory leak in buffer allocation

[src] /lib/Engine/Memory.cpp : Fix destructor to free buffers
[test] /tests/test_memory.cpp : Add test for memory cleanup"

# 3. Second logical change: new feature
git add include/dsa/Stream.h lib/Stream/StreamOps.cpp
git commit -m "[feat] Add stream synchronization primitives

[src] /include/dsa/Stream.h : Define sync interface
[src] /lib/Stream/StreamOps.cpp : Implement sync operations"

# 4. Third logical change: documentation
git add docs/stream_guide.md
git commit -m "[docs] Add stream synchronization guide"

# 5. Push all commits
git push
```

## Allowed Tags

You MUST use one of these tags in square brackets. Three categories exist:

### Category 0: Project-Specific Component Tags

Review **`.claude/git-tags.md`** for project-specific component tags. These custom tags are defined by the project and should be used when they match your changes better than the general tags below.

### Category 1: General Development Tags (lowercase)

Standard commit tags for general development work:

| Tag | Description | Usage Example |
|-----|-------------|---------------|
| **General Development** | | |
| `[feat]` | New features | `[feat] Add support for 2D memory operations` |
| `[fix]` | Bug fixes | `[fix] Correct buffer overflow in memory allocator` |
| `[test]` | Test additions/changes | `[test] Add unit tests for compute engine` |
| `[docs]` | Documentation updates | `[docs] Update DSA dialect reference` |
| `[refactor]` | Code refactoring | `[refactor] Reorganize memory engine hierarchy` |
| `[style]` | Code formatting/style changes | `[style] Apply clang-format to all source files` |
| `[perf]` | Performance improvements | `[perf] Optimize critical path in mapper algorithm` |
| `[chore]` | Routine tasks and maintenance | `[chore] Update .gitignore patterns` |
| **Build & Infrastructure** | | |
| `[build]` | Build system changes | `[build] Update CMake configuration for LLVM 17` |
| `[ci]` | CI/CD changes | `[ci] Add documentation consistency checks` |
| `[bump]` | Dependency/submodule updates | `[bump] Update CIRCT to latest commit` |
| `[utils]` | Development tools/helper scripts | `[utils] Add commit message validation hook` |
| **Development Tools** | | |
| `[tool]` | Development tool changes | `[tool] Add support for new language features` |
| `[mutator]` | Code transformation tools | `[mutator] Add transformation for optimization` |
| `[mapper]` | Mapping tool changes | `[mapper] Improve algorithm efficiency` |
| `[tutorial]` | Tutorial tool changes | `[tutorial] Add integration examples` |
| **Backend Tools** | | |
| `[lang]` | Language tool changes | `[lang] Add support for new features` |
| `[hwgen]` | Hardware generation changes | `[hwgen] Implement performance models` |
| `[est]` | Estimation tool changes | `[est] Add ML model for prediction` |
| `[exp]` | Exploration tool changes | `[exp] Implement optimization algorithms` |
| `[vis]` | Visualization changes | `[vis] Add interactive viewers` |
| **Core Components** | | |
| `[dialect]` | Dialect definitions | `[dialect] Add annotation attributes` |
| `[analysis]` | Analysis infrastructure | `[analysis] Improve detection accuracy` |
| `[lib]` | Library implementations | `[lib] Add utility functions` |
| `[hw]` | Hardware modules | `[hw] Implement scheduling algorithms` |
| `[dv]` | Design verification | `[dv] Add coverage for edge cases` |
| `[systemc]` | SystemC models | `[systemc] Add cycle-accurate models` |
| **Project Management** | | |
| `[example]` | Example programs | `[example] Add benchmark examples` |
| `[rule]` | Rule updates | `[rule] Update documentation guidelines` |
| `[init]` | Initial setup/bootstrap | `[init] Add project structure and build system` |
| **AI & Tooling** | | |
| `[AI]` | AI-assisted development | `[AI] Add AI model configurations` |

### Category 2: Component Tags (for Issue/PR Titles and Squash Merges)

These tags match the issue/PR title format and can be used alone or combined:

| Tag | Description | Usage Example |
|-----|-------------|---------------|
| **Primary Components** | | |
| `[DSACC]` | Top-level C compiler | `[DSACC] Add frontend support` |
| `[DSA++]` | Top-level C++ compiler | `[DSA++] Fix template parsing` |
| `[CC]` | DSA compiler | `[CC] Add new dialect operation` |
| `[SIM]` | Event-driven simulator | `[SIM] Optimize simulation performance` |
| `[MAPPER]` | Place and Route tool | `[MAPPER] Improve routing heuristics` |
| `[HWGEN]` | Hardware generator | `[HWGEN] Add SystemC model` |
| `[GUI]` | Human-computer interface | `[GUI] Update visualization` |
| `[TEST]` | Testing infrastructure | `[TEST] Add unit tests` |
| `[PERF]` | Performance modeling | `[PERF] Add performance counters` |
| `[DOCS]` | Documentation | `[DOCS] Update dialect reference` |
| `[HW]` | Hardware RTL/Netlist | `[HW] Implement PE module` |
| `[DV]` | Design verification | `[DV] Add coverage tests` |
| `[PD]` | Physical design | `[PD] Update floorplan` |
| `[PROTO]` | FPGA prototyping | `[PROTO] Add bitstream generation` |
| `[RUNTIME]` | Firmware and driver | `[RUNTIME] Fix driver issue` |
| `[SIGNOFF]` | Packaging/manufacturing | `[SIGNOFF] Update package spec` |
| **Sub-Area Tags** | | |
| `[Temporal]` | Temporal PE/Switch | `[CC][Temporal] Add scheduling` |
| `[Memory]` | Memory subsystem | `[CC][Memory] Fix addressing` |
| `[CMSIS]` | CMSIS-DSP workloads | `[SIM][CMSIS] Add test` |
| `[SPEC2017]` | SPEC2017 benchmarks | `[TEST][SPEC2017] Add benchmark` |
| `[Greedy]` | Greedy scheduling | `[MAPPER][Greedy] Optimize` |
| `[SimAnneal]` | Simulated Annealing | `[MAPPER][SimAnneal] Tune parameters` |
| `[LLM]` | LLM-based scheduling | `[MAPPER][LLM] Add model` |
| `[RL]` | Reinforcement learning | `[MAPPER][RL] Train agent` |

### Multi-Tag Examples

```
[CC][Temporal][Issue #123] Add dsa.instance operation
[SIM][CMSIS] Fix memory leak in vector multiply test
[MAPPER][Greedy][Issue #45] Improve edge routing heuristics
[TEST] Add unit tests for temporal PE
```

## File Type Classification

When listing file modifications, use these file type tags:

| File Type | Description | Examples |
|-----------|-------------|----------|
| `[src]` | Source code files | `.cpp`, `.cc`, `.c`, `.h`, `.hpp` |
| `[py]` | Python source files | `.py` |
| `[mlir]` | MLIR dialect files | `.mlir`, `.td` |
| `[rtl]` | RTL/Verilog files | `.v`, `.sv`, `.vh`, `.svh` |
| `[test]` | Test files | `test_*.cpp`, `*_test.cpp`, files in `test/` |
| `[docs]` | Documentation | `.md`, `.rst`, `.txt` |
| `[build]` | Build configuration | `CMakeLists.txt`, `*.cmake`, `Makefile`, `setup.py` |
| `[ci]` | CI/CD configuration | `.github/workflows/*`, `.gitlab-ci.yml` |
| `[config]` | Configuration files | `.json`, `.yaml`, `.yml`, `.toml`, `.ini` |
| `[script]` | Scripts and tools | `.sh`, `.bash`, `.tcl`, `.pl` |
| `[rule]` | Rule files | `.md` files in `.claude/rules/` |
| `[ai-config]` | AI tool configuration files | Files in `.claude/`, `.openai/`, etc. |
| `[misc]` | Other files | Any file not fitting above categories |

## Guidelines

1. **Subject Line**:
   - Keep concise (≤100 characters recommended)
   - Use imperative mood ("Add feature" not "Added feature")
   - No period at the end
   - Must start with a valid tag from the list above
   - Must be followed by a blank line

2. **File Modifications Section** (optional but recommended):
   - Format: `[filetype] /relative/path/to/file : Brief reason for change`
   - One file per line
   - Use forward slashes for paths
   - Keep reasons concise and clear
   - Must be followed by a blank line if detailed explanation follows

3. **Detailed Explanation** (optional):
   - Maximum 10 lines
   - Each line must not exceed 75 characters
   - Use to explain the "why" behind changes
   - Describe implementation approach or considerations
   - Mention any side effects or related changes

4. **Authorship Guidelines**:
   - Do not include AI tools as commit authors
   - Do not add Co-Authored-By tags for AI tools
   - Commits should only credit human contributors
   - AI tools are development aids, not collaborators

5. **Examples of Good Commit Messages**:

**Simplified Format Examples:**

Submodule update:
```
[bump] Update CIRCT to latest commit
```

Small change:
```
[fix] Fix typo in error message
```

**Standard Format Examples:**

Simple commit (no file list needed):
```
[fix] Resolve segfault in pattern matcher
```

Tool-specific change:
```
[mapper] Improve graph matching algorithm for better mapping quality

[src] /lib/Mapping/GraphMatching/Matcher.cpp : Implement new heuristics
[test] /tests/cpp/Mapping/test_graph_matching.cpp : Add test cases

The new algorithm reduces mapping time by using better pruning
strategies and improves mapping quality through enhanced cost
functions. This particularly benefits large dataflow graphs.
```

Multi-file commit with explanation:
```
[feat] Add support for 2D memory addressing

[src] /lib/Memory/Address2D.cpp : Implement 2D address calculation
[src] /include/Memory/Interfaces.h : Add interface for stride parameters
[test] /test/Memory/test_2d_addressing.cpp : Add tests for 2D patterns

This feature enables efficient 2D array access patterns.
The implementation uses stride-based addressing to support
row-major and column-major layouts. The interface provides
flexible configuration options for various access patterns.
```

Backend tool update:
```
[hwgen] Add SystemC model for compute PE verification

[py] /tools/hwgen/systemc/compute_pe.py : Create PE model
[rtl] /tools/hwgen/rtl/src/compute_pe/pe_add.sv : Fix RTL bug
[config] /tools/hwgen/systemc/config.yaml : Add model parameters

SystemC model provides cycle-accurate simulation for compute PE.
This enables faster verification iterations compared to RTL sim.
The model exposed a corner case bug in the RTL implementation
which has been fixed.
```

Complex refactoring:
```
[refactor] Reorganize directory structure to follow conventions

[src] /include/project/ : Move all public headers to include directory
[build] /CMakeLists.txt : Update include paths and install targets
[src] /lib/ : Update internal includes to use new paths
[docs] /README.md : Update build instructions for new structure

This refactoring aligns our project structure with coding
standards. All public headers are now in include/project/, while
implementation remains in lib/. This improves modularity and
makes the project easier to integrate as a subproject.
Build configurations have been updated to support both standalone
and in-tree builds.
```

6. **Common Mistakes to Avoid**:
   - [BAD] `Add new feature` - Missing tag
   - [BAD] `[Feature] Add support...` - Tag must be lowercase
   - [BAD] `[new] Add feature` - Invalid tag
   - [BAD] `[feat]: Add feature` - No colon after tag
   - [BAD] `[feat]Add feature` - Missing space after tag
   - [BAD] `[feat] Add feature
[src] file.cpp` - Missing blank line after subject
   - [BAD] `[src] file.cpp - Changed implementation` - Wrong format (use : not -)
   - [BAD] `[source] /lib/file.cpp : Fix bug` - Invalid file type tag
   - [BAD] `[tool-mapper] Fix routing bug` - Use short tag [mapper], not full tool name
   - [BAD] `[python] /tools/lang/lang.py : Update` - Use [py] not [python]
   - [BAD] Lines in detailed explanation that exceed the 75 character limit will make the commit message harder to read in terminal environments
   - [BAD] Using simplified format when changes don't qualify (>2 files or >=10 lines)
   - [BAD] Using full format unnecessarily when simplified format is available

## Validation

The project uses a git commit-msg hook that automatically validates commit messages. If your message doesn't follow the format, the commit will be rejected with helpful error messages.

## Adding New Tags

If you need to add a new tag category, update the `ALLOWED_TAGS` array in the commit-msg hook. This ensures consistency across the project.
