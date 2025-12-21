# Agentize SDK Customization Guide

This guide explains how to customize the Agentize SDK for your specific project.

## Table of Contents

1. [Overview](#overview)
2. [Template Placeholders](#template-placeholders)
3. [Component Tag Configuration](#component-tag-configuration)
4. [Custom Rules](#custom-rules)
5. [Build Command Configuration](#build-command-configuration)
6. [Agent Customization](#agent-customization)
7. [Examples by Project Type](#examples-by-project-type)

---

## Overview

The Agentize SDK is installed with sensible defaults, but you'll want to customize it to match your project's:
- **Component structure** (L1/L2 tags)
- **Build commands** (make, cargo, npm, etc.)
- **Coding conventions** (naming, testing, documentation standards)
- **Development workflows** (release process, deployment procedures)

**Important**: For persistent customizations that should survive SDK updates, always use `custom-project-rules.md` - this file is never touched by SDK updates.

---

## Understanding File Ownership

Agentize categorizes files to safely handle SDK updates while preserving your customizations.

### File Categories

#### SDK-Owned Files (Replaced on Update)

These files are maintained by the Agentize SDK and will be replaced during `make agentize AGENTIZE_MODE=update`:

- **Agents**: `agents/*.md` (all agent definitions)
- **Commands**: `commands/*.md` (all command definitions)
- **Core Rules**: Most files in `rules/` except `custom-project-rules.md` and `custom-workflows.md`
- **Skills**: `skills/**/*` (all skill definitions)
- **Hooks**: `hooks/**/*` (git hooks and event handlers)
- **Documentation**: `README.md`

**Do not customize these files directly** - your changes will be lost on update. Instead, use the user-owned files below.

#### User-Owned Files (Never Touched)

These files are yours to customize and will never be modified by SDK updates:

- `rules/custom-project-rules.md` - Your project-specific coding conventions
- `rules/custom-workflows.md` - Your team's workflows and processes

**Best practice**: Put all project-specific rules and customizations in these files.

#### Templated Files (Interactive Prompts)

These files contain project-specific values (like `${PROJECT_NAME}`) and require your input during updates:

- `CLAUDE.md` - Project README for Claude Code
- `git-tags.md` - Custom git commit tags
- `settings.json` - Claude Code settings
- `PROJECT_CONFIG.md` - Project-specific configuration

**Update behavior**: You'll see a diff and can choose to:
- Accept SDK changes (overwrite)
- Keep your version (skip)
- Manually merge later (skip for now)

### Customization Best Practices

1. **Always use `custom-project-rules.md`** for project-specific conventions
2. **Never modify SDK-owned files** unless you're prepared to lose changes
3. **Track `.claude/` in git** to see what changes during updates
4. **Review diff previews carefully** when prompted for templated files

---

## Template Placeholders

During installation, the following placeholders are substituted:

| Placeholder | Makefile Variable | Example Value | Where Used |
|-------------|-------------------|---------------|------------|
| `${PROJECT_NAME}` | `AGENTIZE_PROJ_NAME` | "My Project" | CLAUDE.md, docs |
| `${PROJ_DESC}` | `AGENTIZE_PROJ_DESC` | "A web application" | CLAUDE.md |
| `${COMPONENT_TAGS}` | `AGENTIZE_COMPONENT_TAGS` | `[CORE],[API],[UI]` | CLAUDE.md, agents |

**After Installation**: Review `.claude/CLAUDE.md` and update these values if needed.

---

## Component Tag Configuration

### What are L1/L2 Tags?

Component tags organize your codebase into logical areas:
- **L1 (Primary Component)**: Top-level modules (e.g., CORE, API, UI, TEST, DOCS)
- **L2 (Subcomponent)**: Feature areas within L1 (e.g., Auth, Database, Payment)

### Configuring Tags in CLAUDE.md

Edit `.claude/CLAUDE.md` and update the component mapping:

```markdown
## Component Tags

| L1 Tag | Description | Example Paths |
|--------|-------------|---------------|
| [CORE] | Core business logic | `src/core/`, `lib/` |
| [API] | REST API endpoints | `src/api/`, `routes/` |
| [UI] | User interface | `src/components/`, `views/` |
| [DB] | Database layer | `src/models/`, `migrations/` |
| [TEST] | Test infrastructure | `tests/`, `__tests__/` |
| [DOCS] | Documentation | `docs/` |

| L2 Tag | Description | Parent L1 |
|--------|-------------|-----------|
| [Auth] | Authentication/authorization | CORE, API |
| [Payment] | Payment processing | CORE, API |
| [Analytics] | Analytics and reporting | UI, CORE |
```

### Updating Agent Component Mappings

If you change L1/L2 tags, update `agents/project-manager.md`:

```markdown
## Component Mapping

| Issue Tag | GitHub Label | Project Field Value |
|-----------|--------------|---------------------|
| [CORE] | L1:CORE | CORE |
| [API] | L1:API | API |
| [UI] | L1:UI | UI |
```

---

## Custom Rules

The SDK provides two extension points for project-specific rules:

### 1. custom-project-rules.md

**Purpose**: Define coding conventions, naming standards, testing requirements.

**Location**: `.claude/rules/custom-project-rules.md`

**Example**:
```markdown
### Naming Conventions

- Use camelCase for JavaScript/TypeScript variables
- Use PascalCase for React component names
- Use kebab-case for file names

### Testing Requirements

- Minimum 80% code coverage for new code
- All public APIs must have integration tests
- Test files must be colocated with source files (e.g., `Component.test.tsx`)

### Code Organization

- All API endpoints must have corresponding tests in `tests/api/`
- Each feature module must have a README.md explaining its purpose
```

### 2. custom-workflows.md

**Purpose**: Define development workflows, release processes, deployment procedures.

**Location**: `.claude/rules/custom-workflows.md`

**Example**:
```markdown
### Development Workflow

1. Pick issue from GitHub Project backlog
2. Create feature branch from `develop`
3. Implement changes following TDD
4. Create PR to `develop`
5. Address review comments
6. Merge after CI passes + 1 approval

### Release Workflow

1. Create release branch from `develop`
2. Update version in package.json
3. Run full test suite
4. Generate changelog
5. Create PR to `main`
6. Tag release after merge
7. Deploy to production via GitHub Actions

### Deployment Process

- Staging: Automatic on merge to `develop`
- Production: Manual approval required
- Rollback: Use deployment platform rollback feature
- Monitor for 30 minutes after deployment
```

---

## Build Command Configuration

The SDK expects three standard commands in your project:

### 1. Environment Setup

**Command**: `source setup.sh`

**Purpose**: Load environment variables, activate virtual environments, set PATH

**Example** (`setup.sh`):
```bash
#!/bin/bash
# Activate Python virtual environment
source venv/bin/activate

# Set project environment variables
export DATABASE_URL="postgresql://localhost/mydb"
export API_KEY="dev-key"

# Add local bin to PATH
export PATH="$PWD/node_modules/.bin:$PATH"
```

### 2. Build

**Command**: `make build`

**Purpose**: Compile/build the project

**Examples** (in your `Makefile`):

**Python**:
```makefile
build:
	pip install -r requirements.txt
	python -m compileall .
```

**Node.js**:
```makefile
build:
	npm install
	npm run build
```

**Rust**:
```makefile
build:
	cargo build --release
```

**Go**:
```makefile
build:
	go build -o bin/myapp ./cmd/myapp
```

### 3. Test

**Command**: `make test`

**Purpose**: Run test suite

**Examples**:

**Python**:
```makefile
test:
	pytest tests/ -v --cov=src
```

**Node.js**:
```makefile
test:
	npm test
	npm run test:integration
```

**Rust**:
```makefile
test:
	cargo test
```

**Go**:
```makefile
test:
	go test ./... -v
```

### Updating Agent Expectations

If you use different build commands, update `agents/pre-commit-gate.md`:

```markdown
## Build Commands

\`\`\`bash
# Your custom build commands
npm run lint
npm run build
npm test
\`\`\`
```

---

## Agent Customization

### Adjusting Triage Thresholds

Edit `commands/issue2impl.md` to change triage criteria:

```markdown
| Tier | Criteria | Workflow Modification |
|------|----------|------------------------|
| `fast` | ANY of: single file, doc-only, <30 lines, `quick-fix` label | ... |
| `standard` | Default | ... |
| `extended` | ANY of: multi-component, >2000 lines, `complex` label | ... |
```

### Customizing Code Review Standards

Edit `agents/code-reviewer.md` to adjust scoring criteria:

```markdown
## Scoring Rubric

| Score Range | Interpretation | Action |
|-------------|---------------|--------|
| 90-100 | Excellent | Proceed |
| 81-89 | Good | Proceed |
| 70-80 | Acceptable with minor fixes | Request fixes |
| <70 | Needs significant improvement | Block |
```

### Modifying Milestone Thresholds

Edit `skills/workflow-reference/SKILL.md`:

```markdown
| Lines Changed | Action |
|---------------|--------|
| < 500 | Continue normally |
| 500-800 | Monitor |
| 800-1000 | Consider milestone |
| > 1000 | **Must create milestone** |
```

---

## Examples by Project Type

### Web Application (React + Node.js)

**Component Tags**:
```markdown
[FRONTEND] - React components, UI logic
[BACKEND] - Express API, business logic
[DB] - Database models, migrations
[AUTH] - Authentication/authorization
[TEST] - Test infrastructure
```

**Build Commands** (`Makefile`):
```makefile
.PHONY: build test env-script

env-script:
	@echo "source setup.sh"

build:
	npm install
	npm run build

test:
	npm test
	npm run test:e2e
```

**setup.sh**:
```bash
#!/bin/bash
export NODE_ENV=development
export DATABASE_URL="postgresql://localhost/myapp"
```

---

### Python Data Science Project

**Component Tags**:
```markdown
[ANALYSIS] - Data analysis notebooks
[MODEL] - ML model training
[PIPELINE] - Data pipelines
[API] - Model serving API
[TEST] - Unit and integration tests
```

**Build Commands** (`Makefile`):
```makefile
.PHONY: build test env-script

env-script:
	@echo "source setup.sh"

build:
	pip install -r requirements.txt
	python -m compileall src/

test:
	pytest tests/ -v --cov=src
	pytest tests/integration/ -v
```

**setup.sh**:
```bash
#!/bin/bash
source venv/bin/activate
export PYTHONPATH="${PYTHONPATH}:${PWD}/src"
```

---

### Rust CLI Tool

**Component Tags**:
```markdown
[CORE] - Core library
[CLI] - Command-line interface
[CONFIG] - Configuration management
[TEST] - Test infrastructure
[DOCS] - Documentation
```

**Build Commands** (`Makefile`):
```makefile
.PHONY: build test env-script

env-script:
	@echo "# No environment setup needed"

build:
	cargo build --release

test:
	cargo test
	cargo clippy -- -D warnings
```

**setup.sh**:
```bash
#!/bin/bash
# Rust projects typically don't need environment setup
export RUST_BACKTRACE=1
```

---

### Monorepo (Multiple Services)

**Component Tags**:
```markdown
[AUTH] - Authentication service
[API] - API gateway
[DB] - Shared database layer
[UI] - Frontend application
[INFRA] - Infrastructure as code
[TEST] - Cross-service tests
```

**Build Commands** (`Makefile`):
```makefile
.PHONY: build test env-script

env-script:
	@echo "source setup.sh"

build:
	# Build all services
	make -C services/auth build
	make -C services/api build
	make -C services/ui build

test:
	# Run all tests
	make -C services/auth test
	make -C services/api test
	make -C services/ui test
	# Run integration tests
	./scripts/integration-tests.sh
```

---

## Updating Your SDK

When new Agentize features are released:

1. **Pull latest Agentize SDK**:
   ```bash
   cd /path/to/agentize
   git pull origin main
   ```

2. **Update your project**:
   ```bash
   cd agentize/
   make agentize \
     AGENTIZE_MASTER_PROJ=/path/to/your-project \
     AGENTIZE_MODE=update
   ```

3. **Review changes**:
   - Check backup location (reported in output)
   - Review any templated file prompts carefully
   - Run `git diff .claude/` to see what changed

4. **Test your workflows**:
   - Ensure `/gen-handoff`, `/issue2impl`, etc. still work
   - Validate any custom agents/commands if you have them

### Troubleshooting Updates

**Problem**: Update fails partway through
- **Solution**: Restore from backup: `rm -rf .claude && mv .claude.backup.* .claude`

**Problem**: Lost some customizations
- **Solution**: Check backup, copy customizations to `custom-project-rules.md`

**Problem**: Templated file has conflicts
- **Solution**: Skip during update, manually merge from `.claude.backup.*/`

---

## Validation Checklist

After customization, verify:

- [ ] `.claude/CLAUDE.md` has correct project name, description, and component tags
- [ ] `rules/custom-project-rules.md` documents your coding conventions
- [ ] `rules/custom-workflows.md` documents your development workflows
- [ ] `setup.sh` correctly sets up your development environment
- [ ] `make build` successfully builds your project
- [ ] `make test` successfully runs your test suite
- [ ] `agents/project-manager.md` component mapping matches your tags
- [ ] `/issue2impl` command works end-to-end on a test issue

---

## Troubleshooting

### Issue: "Build command not found"

**Solution**: Ensure `Makefile` has `build` target and it's executable:
```bash
make build  # Test manually
```

### Issue: "Environment setup failed"

**Solution**: Check `setup.sh` has execute permissions and runs without errors:
```bash
chmod +x setup.sh
source setup.sh
```

### Issue: "Component tags not recognized"

**Solution**: Update both:
1. `.claude/CLAUDE.md` - component tag table
2. `agents/project-manager.md` - component mapping table

### Issue: "GitHub Project integration fails"

**Solution**: Run `gh auth refresh -s project` to add project permissions

---

## Getting Help

1. Check existing issues: https://github.com/your-org/agentize/issues
2. Review reference-design for examples
3. Consult Claude Code documentation: https://claude.com/claude-code

---

## Contributing Back

If you create useful customizations, consider contributing them back:
1. Create an example configuration in `examples/`
2. Document your use case
3. Submit a PR to the Agentize repository
