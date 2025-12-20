# Custom Project Rules

This file contains project-specific rules and guidelines that extend the core Agentize rules.

## Purpose

Use this file to define:
- Project-specific coding conventions
- Custom file organization requirements
- Project-specific testing requirements
- Team-specific workflows
- Domain-specific guidelines

## Template

### Code Organization

<!-- Example:
- All API endpoints must have corresponding tests in `tests/api/`
- Each module must have a README.md explaining its purpose
- Configuration files must be in `config/` directory
-->

### Naming Conventions

<!-- Example:
- Use camelCase for JavaScript/TypeScript variables
- Use snake_case for Python variables
- Use kebab-case for file names
- Component names must match their file names
-->

### Testing Requirements

<!-- Example:
- Minimum 80% code coverage for new code
- All public APIs must have integration tests
- Critical paths must have end-to-end tests
- Test files must be colocated with source files
-->

### Documentation Standards

<!-- Example:
- All public functions must have docstrings/JSDoc
- Complex algorithms must have inline comments explaining the approach
- Architecture decisions must be documented in `docs/architecture/`
- API changes must update OpenAPI/Swagger specs
-->

### Code Review Guidelines

<!-- Example:
- PRs must not exceed 500 lines of changes
- All PRs require at least one approval
- Security-sensitive changes require security team review
- Breaking changes require tech lead approval
-->

### Git Workflow

<!-- Example:
- Branch naming: `feature/`, `bugfix/`, `hotfix/`
- Commit messages must reference issue numbers
- Force pushes are not allowed on main/develop branches
- Squash merging preferred for feature branches
-->

### Performance Requirements

<!-- Example:
- API responses must be under 200ms for 95th percentile
- Page load times must be under 2 seconds
- Database queries must use proper indexing
- N+1 queries are not allowed
-->

### Security Guidelines

<!-- Example:
- Never commit secrets or API keys
- All user inputs must be validated and sanitized
- Authentication required for all non-public endpoints
- SQL injection prevention via parameterized queries
-->

## Custom Tags and Labels

<!-- Define project-specific component tags -->

### Component Tags (L1)
<!-- Example:
- [CORE] - Core business logic
- [API] - REST API endpoints
- [UI] - User interface components
- [DB] - Database layer
- [AUTH] - Authentication/authorization
-->

### Feature Area Tags (L2)
<!-- Example:
- [Payment] - Payment processing features
- [User] - User management features
- [Analytics] - Analytics and reporting
-->

## Project-Specific Patterns

<!-- Document patterns that developers should follow -->

### Error Handling Pattern
<!-- Example: How to handle errors in this project -->

### Logging Pattern
<!-- Example: How to structure log messages -->

### Configuration Management
<!-- Example: How to add new config options -->

---

**Note**: These rules complement (not replace) the core rules in other `.claude/rules/*.md` files.
