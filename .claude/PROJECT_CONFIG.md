# Project Configuration Guide

This guide helps you customize the Agentize AI workflow for your specific project.

## Quick Start Checklist

After running `make agentize`, customize these files:

- [ ] `.claude/git-tags.md` - **Customize component tags for your project**
- [ ] `.claude/CLAUDE.md` - Main project configuration
- [ ] `.claude/settings.json` - Permissions and hooks
- [ ] `.claude/rules/custom-project-rules.md` - Project-specific rules
- [ ] `docs/CLAUDE.md` - Project documentation

## Configuration Files

### 1. `.claude/git-tags.md` **[IMPORTANT - Start Here]**

**Project-specific component tags for git commits and issues.**

This file defines the component tags used throughout your project. Claude Code automatically reads this file when creating commits and issues.

#### How to Customize

Edit `.claude/git-tags.md` to define tags that match your project structure:

```markdown
# Git Component Tags

This file defines the component tags used in git commit messages and issue/PR titles for ${PROJECT_NAME}.

## Component Tags

You can customize these tags to match your project structure:

**Example tags** (replace with your actual components):
- [CORE] - Core library/framework code
- [API] - REST API implementation
- [UI] - User interface components
- [DB] - Database layer
- [STORAGE] - Data storage and persistence
- [AUTH] - Authentication and authorization
- [TEST] - Testing utilities
- [DOCS] - Documentation
```

#### Tag Selection Guidelines

Choose tags that:
- **Match your architecture**: Reflect major components or layers
- **Are mutually exclusive**: Each change should clearly belong to one primary tag
- **Stay stable**: Avoid renaming tags frequently (breaks historical analysis)
- **Scale appropriately**: 5-12 tags for most projects

#### Examples by Project Type

**Web Application:**
```
[FRONTEND], [BACKEND], [DB], [API], [AUTH], [UI], [TEST], [DOCS]
```

**Python Library:**
```
[CORE], [API], [CLI], [UTILS], [TEST], [DOCS], [BUILD]
```

**C++ System Software:**
```
[CORE], [MEMORY], [SCHEDULER], [IO], [NETWORK], [TEST], [DOCS], [BUILD]
```

**Multi-Language Project:**
```
[PYTHON], [CPP], [BINDINGS], [API], [TEST], [DOCS], [BUILD]
```

### 2. `.claude/CLAUDE.md`

**Main project configuration file.** Update these sections:

#### Project Overview
```markdown
${PROJECT_NAME}

TODO: Add project description
```
Replace with your actual project description.

#### Component Tags Reference

The component tags are defined in `.claude/git-tags.md`. Review and customize that file first.

#### Build Commands
Update with your project's actual build commands:
```bash
source setup.sh              # Your environment setup
make build                   # Your build command
make test                    # Your test command
```

#### Project-Specific Tools
List any custom tools your project uses:
```markdown
| Tool | Purpose |
|------|---------|
| `my-tool` | Description of what it does |
```

### 3. `.claude/settings.json`

**Permissions and hooks configuration.**

#### Adding Project-Specific Tools
Find the section:
```json
"Bash(echo PROJECT-SPECIFIC TOOLS - TODO: Add your tools here)",
```

Add your tools below it:
```json
"Bash(your-tool:*)",
"Bash(./build/bin/your-compiler:*)",
```

#### Common Tool Patterns
- **Build tools**: `ninja:*`, `gradle:*`, `cargo:*`
- **Testing tools**: `pytest:*`, `jest:*`, `cargo test:*`
- **Linters**: `eslint:*`, `black:*`, `rustfmt:*`
- **Package managers**: `npm:*`, `pip:*`, `yarn:*`

### 4. `.claude/rules/custom-project-rules.md`

**Project-specific rules and guidelines.**

Add rules specific to your project:
- Coding conventions
- File organization requirements
- Testing requirements
- Documentation standards

Example:
```markdown
# Custom Project Rules

## Code Organization
- All API endpoints must have corresponding tests in `tests/api/`
- Each module must have a README.md

## Testing Requirements
- Minimum 80% code coverage
- All public APIs must have integration tests

## Documentation
- All public functions must have docstrings
- Architecture decisions documented in `docs/architecture/`
```

### 5. `docs/CLAUDE.md`

**Project documentation template.**

Fill in:
- Architecture overview
- Component descriptions
- Development guide
- API reference

## Standard Interface

Your project must implement these standard commands:

### Environment Setup
```bash
source setup.sh
```
Creates a `setup.sh` script that sets up the development environment (PATH, environment variables, etc.).

### Build
```bash
make build
```
Builds the entire project.

### Test
```bash
make test
```
Runs all tests.

## Customizing Agents and Commands

### Understanding Component Tags

Agents and commands use component tags to organize work. Define your tags in `.claude/git-tags.md` and use them consistently in:
- Git commit messages
- GitHub issue labels and titles
- PR titles
- Milestone tracking

Claude Code automatically reads `.claude/git-tags.md` when suggesting component tags, so keeping this file up-to-date ensures accurate tagging

### Modifying Agents

Agent files are in `.claude/agents/`. Generally, you don't need to modify these, but you can if needed:
- `milestone-generator.md` - Customize milestone formats
- `project-manager.md` - Customize GitHub Project integration

### Custom Commands

Add custom commands in `.claude/commands/`. Follow existing patterns.

## Hooks

### Session Init Hook (`.claude/hooks/session-init.sh`)

Runs when you start a Claude Code session. Customize to:
- Load environment modules
- Display project status
- Check for updates

### Post-Edit Hook (`.claude/hooks/post-edit.sh`)

Runs after file edits. Customize to:
- Auto-format code
- Run linters
- Update generated files

## Permissions Strategy

### Allow by Default
- Read operations (ls, cat, find, grep)
- Standard build tools (make, cmake)
- Git read operations (status, diff, log)
- GitHub read operations (gh pr view, gh issue list)

### Ask Before Running
- Git write operations (commit, push)
- GitHub write operations (gh issue create, gh pr create)
- General-purpose interpreters (python3, node)

### Deny
- `cd` command (saves tokens, use absolute paths instead)
- Destructive operations (git reset, git restore)

## Troubleshooting

### Agents Not Finding Tools
Add your tools to `settings.json` permissions.

### Build Commands Failing
Ensure `make build` and `make test` are implemented in your project's Makefile.

### Environment Not Loaded
Check that `setup.sh` is properly configured and sourced.

## Getting Help

- Check `.claude/README.md` for component reference
- Read `.claude/CUSTOMIZATION_GUIDE.md` for advanced topics
- Review reference implementations in `.claude/agents/`, `.claude/commands/`

---

**Need more help?** See the [Agentize README](https://github.com/your-org/agentize) for full documentation.
