# Git Component Tags

This file defines the component tags used in git commit messages and issue/PR titles for MyProject.

## Component Tags

You can customize these tags to match your project structure:

**Example tags** (replace with your actual components):
- [CORE] - Core functionality and business logic
- [API] - API endpoints and interfaces
- [UI] - User interface components
- [TEST] - Testing infrastructure and utilities
- [DOCS] - Documentation and guides

## Usage

These tags are used in:
- Git commit messages: `[CORE] Add feature X`
- Issue/PR titles: `[API][Auth] Fix login bug`
- Multi-tag format: `[CORE][Memory][Issue #42] Optimize allocator`

## Guidelines

### 1. Primary Components (L1 Tags)

Top-level areas of your project:
- Use UPPERCASE for consistency
- Keep them short (4-6 characters ideal)
- Examples: [CORE], [API], [UI], [CLI], [TEST], [DOCS]

### 2. Sub-Area Tags (L2 Tags)

More specific categorization:
- Combine with primary tags: `[API][Auth]`, `[CORE][Memory]`
- Use when you need finer granularity
- Keep them focused and specific

### 3. Tag Definitions

Document what each tag represents to help contributors understand the project structure:

**Web Application Example:**
- [FRONTEND] - React UI components and pages
- [BACKEND] - Node.js/Express API server
- [DB] - Database schemas and migrations
- [AUTH] - Authentication and authorization
- [INFRA] - Docker, CI/CD, deployment configs
- [TEST] - Testing utilities and fixtures
- [DOCS] - Documentation and guides

**System Software Example:**
- [KERNEL] - Core kernel modules
- [DRIVER] - Device drivers
- [FS] - Filesystem implementation
- [NET] - Network stack
- [TOOLS] - Userspace utilities
- [TEST] - Unit and integration tests
- [DOCS] - API documentation

**Library Project Example:**
- [CORE] - Core library implementation
- [API] - Public API surface
- [IMPL] - Internal implementation details
- [BENCH] - Benchmarks
- [EXAMPLES] - Example programs
- [TEST] - Test suite
- [DOCS] - Library documentation

## Customization

To customize for your project:

1. **Identify your components** - What are the main areas of your codebase?
2. **Define clear boundaries** - Ensure each component has a well-defined scope
3. **Update this file** - Replace the example tags above with your actual components
4. **Document each tag** - Explain what each tag represents
5. **Share with team** - Ensure everyone understands the tagging system

## Integration

This file is referenced by `.claude/rules/git-commit-format.md` when creating commits.

See `.claude/rules/issue-pr-format.md` for full issue/PR title format specification.
