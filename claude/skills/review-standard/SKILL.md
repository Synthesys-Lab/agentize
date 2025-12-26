---
name: review-standard
description: Systematic code review skill checking documentation quality and promoting code reuse
---

# Review Standard

Comprehensive code review skill ensuring quality, consistency, and adherence to project documentation and code reuse standards before merging to main branch.

## Review Philosophy

- **Systematic**: Consistent process across all reviews
- **Standards-based**: Enforce `document-guideline` skill requirements
- **Reuse-focused**: Prevent reinventing the wheel
- **Actionable**: Specific, implementable recommendations
- **Context-aware**: Understand changes within broader architecture

### Review Objectives

Every review assesses:
1. **Documentation Quality**: Compliance with `document-guideline` standards
2. **Code Quality & Reuse**: Best practices and existing utility leverage
3. **Advanced Code Quality**: Indirection, repetition patterns, module focus, interface clarity, type safety, change impact

Reviews provide recommendations - final merge decisions remain with maintainers.

## Review Process

When `/code-review` is invoked:
1. Gather context: Changed files and full diff
2. Phase 1: Validate documentation completeness
3. Phase 2: Assess code quality and reuse opportunities
4. Phase 3: Evaluate indirection, type safety, and change scope
5. Generate structured, actionable report

## Phase 1: Documentation Quality Review

Validates compliance with `document-guideline` standards.

**Documentation & Comment Content Principle**: All documentation and code comments should focus on current design rationale, not historical changes or comparisons. Explain *why* the current approach exists and *how* it works, not how it improved from previous versions.

**Common violations**:
- ❌ Documentation: "This design reduces 30% LOC compared to previous version"
- ❌ Documentation: "Simplified from X to Y lines"
- ❌ Comment: "// Refactored to be 40% faster than old implementation"
- ❌ Comment: "# Changed from recursive to iterative approach"
- ✅ Documentation: "This design provides unified interface across modules"
- ✅ Documentation: "Uses dataclass for explicit attribute declaration and type safety"
- ✅ Comment: "// Use iterative approach to avoid stack overflow for large inputs"
- ✅ Comment: "# Cache results to avoid redundant API calls"

### Check 1: Documentation & Comment Content Quality

**Standard**: Documentation and comments must focus on current rationale, not historical comparisons.

**Check**: Review documentation files and code comments for historical references or improvement claims.

**Example findings**:
```
❌ Historical comparison in documentation
   README.md:18 - "This implementation reduced LOC by 40% compared to v1.0"

   Recommendation: Rewrite to focus on current design:
   "This implementation uses a unified interface to simplify module interactions"

❌ Historical reference in code comment
   src/parser.py:45 - "# Changed from regex to AST parsing for better performance"

   Recommendation: Explain current rationale:
   "# Use AST parsing to handle nested structures and provide detailed error locations"
```

### Check 2: Folder README.md Files

**Standard**: Every folder (except hidden) must have `README.md`.

**Check**: For each directory with changes, verify `README.md` exists and reflects new files.

**Common issues**:
- New folder without `README.md`
- Existing `README.md` not updated for new files

**Example finding**:
```
❌ Missing folder documentation
   claude/skills/new-skill/ - No README.md found

   Recommendation: Create README.md documenting folder purpose, key files, integration points
```

### Check 3: Source Code Interface Documentation

**Standard**: Every source file (`.py`, `.c`, `.cpp`, `.cxx`, `.cc`) must have companion `.md` file.

**Check**: Verify `.md` file exists and documents:
- External Interface: Public APIs with signatures, inputs/outputs, error conditions
- Internal Helpers: Private functions and complex algorithms

**Common issues**:
- Missing `.md` file
- `.md` exists but incomplete (missing public functions)
- Documentation doesn't match implementation

**Example finding**:
```
❌ Missing interface documentation
   src/utils/validator.py - No validator.md found

   Recommendation: Create validator.md with External Interface and Internal Helpers sections

❌ Incomplete interface documentation
   src/api/handler.md - Missing handle_request() function

   Recommendation: Add handle_request() signature, parameters, return value, error conditions
```

### Check 4: Test Documentation

**Standard**: Test files need documentation explaining what they test.

**Acceptable formats**:
- Inline comments (preferred for simple tests): `# Test 1: Description`
- Companion `.md` file (for complex suites)

**Check**: Test files have inline comments or `.md` companion documenting test purpose and expected outcomes.

**Example finding**:
```
❌ Missing test documentation
   tests/test_validation.sh - No inline comments or companion .md

   Recommendation: Add inline comments:
   # Test 1: Validator accepts valid input (expect: exit 0)
   # Test 2: Validator rejects malformed input (expect: exit 1, error message)
```

### Check 5: Design Documentation

**Standard**: Architectural changes should have design docs in `docs/`.

**When expected**: New subsystems, major features, architectural changes, significant refactoring

**Check**: Look for design doc references in commits; check `docs/` for relevant updates.

**Note**: Design docs require human judgment, not enforced by linting.

**Example finding**:
```
⚠️  Consider adding design documentation
   Changes introduce new authentication subsystem across 5 files

   Recommendation: Consider docs/authentication.md documenting architecture, flow, integration, security
```

### Check 6: Documentation Linter

**Tool**: `scripts/lint-documentation.sh`

Validates structural requirements (folder READMEs, source `.md` companions, test docs).

**Check**: Run linter or verify it would pass. On milestone branches, `--no-verify` bypass acceptable if documentation complete.

**Example finding**:
```
❌ Documentation linter would fail
   Missing: src/utils/parser.md, claude/commands/README.md

   Recommendation: Add missing documentation before final merge
```

## Phase 2: Code Quality & Reuse Review

Assesses code quality and identifies reuse opportunities.

### Check 1: Code Duplication

**Objective**: Find duplicate or similar code within changes.

**Look for**: Similar function names/logic, repeated code blocks, duplicate validation/error handling.

**Example finding**:
```
❌ Code duplication detected
   src/new_feature.py:42 - parse_date() duplicates existing logic
   Existing: src/utils/date_parser.py:parse_date()

   Recommendation: Import and use existing parse_date() instead of reimplementing
```

### Check 2: Local Utility Reuse

**Objective**: Find existing project utilities that could replace new code.

**Common categories**: Validation, parsing, formatting, file operations, git operations.

**Check**: Search `src/utils/`, `scripts/` for existing utilities matching new code patterns.

**Example finding**:
```
❌ Reinventing the wheel - local utility exists
   src/api/handler.py:67 - Manual JSON validation
   Existing: src/utils/validators.py:validate_json()

   Recommendation: Replace with: from src.utils.validators import validate_json
```

### Check 3: External Library Reuse

**Objective**: Find standard libraries or packages that could replace custom code.

**Common reinvented wheels**:
- Custom arg parsing (use `argparse`)
- Manual HTTP (use `requests`)
- Custom date parsing (use `dateutil`)
- Manual config parsing (use `configparser`, `yaml`)

**Example finding**:
```
❌ Reinventing the wheel - standard library exists
   src/cli.py:23-45 - Custom argument parsing

   Recommendation: Use argparse for automatic --help, type conversion, error handling
```

### Check 4: Dependencies Review

**Objective**: Check for redundant or conflicting dependencies.

**Look for**: Multiple libraries for same purpose, unused imports, non-standard when standard exists.

**Example finding**:
```
⚠️  Dependency consideration
   src/fetcher.py:5 - Added httpx when requests already used project-wide

   Recommendation: Use consistent HTTP library unless httpx provides required feature
```

### Check 5: Project Conventions

**Objective**: Ensure code follows existing patterns and architecture.

**Check**: Error handling approach, naming conventions, module organization, configuration management, logging patterns.

**Example finding**:
```
⚠️  Inconsistent with project patterns
   src/new_module.py - Uses camelCase function names
   Project convention: snake_case (see src/utils/, src/api/)

   Recommendation: Rename to match project style (parseInput → parse_input)
```

### Check 6: Commit Hygiene

**Objective**: Ensure only appropriate files are committed and debug code is removed.

**Check for inappropriate files**:
- Temporary files: `.tmp`, `*.swp`, `*.bak`, `*~`, `.DS_Store`
- Build artifacts: `*.pyc`, `__pycache__/`, `build/`, `dist/`, `*.o`, `*.so`
- IDE/editor files: `.vscode/`, `.idea/`, `*.sublime-*`
- Local config: `.env`, `*.local.*`, `settings.local.json`
- Log files: `*.log`, `debug.txt`

**Check for debug code**:
- Debug print statements: `console.log()`, `print("debug")`, `printf("DEBUG")`
- Commented-out debug code blocks
- Debug-only imports: `import pdb; pdb.set_trace()`
- Verbose logging left in production code
- Test data hardcoded in source files

**Example findings**:
```
❌ Temporary file committed
   .tmp/debug-output.txt - Temporary file should not be committed

   Recommendation: Remove from staging and add pattern to .gitignore

❌ Debug code left in commit
   src/api/handler.py:23 - console.log("DEBUG: request received")

   Recommendation: Remove debug logging before commit

⚠️  Local configuration file
   config/settings.local.json - Local config file committed

   Recommendation: Move to settings.example.json or add to .gitignore
   Users should copy example to .local version

❌ Debug breakpoint left in code
   src/utils/parser.py:45 - import pdb; pdb.set_trace()

   Recommendation: Remove debugger statement
```

## Phase 3: Advanced Code Quality Review

Deep analysis of code structure, type safety, and architectural boundaries.

### Check 1: Indirection Analysis

**Objective**: Identify unnecessary wrappers and abstractions.

**Look for**:
- Classes that only delegate without adding value
- Functions wrapping existing functions without transformation
- Premature abstractions without clear need

**Example finding**:
```
❌ Unnecessary indirection
   src/utils/request_wrapper.py:12 - RequestWrapper only delegates to requests.get()

   Recommendation: Remove wrapper and use requests.get() directly
   OR document added value (retries, logging, auth) and implement meaningfully
```

### Check 2: Code Repetition Deep Analysis

**Objective**: Identify patterns suggesting need for unified interface.

**Look for**: Multiple similar functions with variations, repeated patterns, copy-pasted logic.

**Balance**: Generalize when pattern appears 3+ times with clear abstraction. Flag premature abstraction adding complexity.

**Example finding**:
```
⚠️  Code repetition pattern detected
   src/validators.py - Three similar functions: validate_email(), validate_phone(), validate_url()
   All follow same pattern: regex match, return True/False, optional error message

   Recommendation: Consider unified interface validate_format(value, pattern, error_msg)
   Only proceed if this simplifies codebase. Keep separate if unique logic beyond pattern matching.
```

### Check 3: Module Focus Validation

**Objective**: Ensure modules maintain single responsibility, don't repurpose code paths.

**Look for**:
- Borrowing code paths for unrelated features
- Functionality belonging in different module
- Module scope creep (utils as catch-all)

**Differentiate**: Module-specific helpers (keep private) vs. reusable utilities (move to shared `utils/`).

**Example finding**:
```
❌ Module focus violation
   src/api/user_handler.py:67 - Added CSV parsing logic unrelated to API handling

   Recommendation: Extract to appropriate location:
   - If CSV parsing reusable → src/utils/csv_parser.py
   - If specific to user data → src/models/user_csv.py
```

### Check 4: Interface Boundary Clarity

**Objective**: Verify clear separation of declaration, usage, and error handling.

**Prefer**: `@dataclass` for structured data (pre-declares attributes, type safety, auto-generated methods).

**Check for**:
- `getattr`/`setattr` instead of explicit attributes
- None-handling scattered at usage sites
- Mixing mandatory/optional attributes without clear contract

**Example finding**:
```
❌ Dynamic attribute access reduces clarity
   src/models/config.py:23 - getattr(config, 'timeout', 30)
   Unclear if 'timeout' is mandatory or optional

   Recommendation: Use @dataclass with explicit declaration:
   @dataclass
   class Config:
       timeout: int = 30  # Optional with default
       host: str          # Mandatory

   Benefits: Clear contract, type safety, IDE autocomplete

⚠️  None-handling at usage site
   src/api/handler.py:45 - if user.email is not None: send_email(user.email)

   Recommendation: Handle at accessor level:
   - If mandatory: Validate email never None at creation
   - If optional: Provide has_email() method or email property with default
```

### Check 5: Type Safety & Magic Numbers

**Objective**: Enforce type annotations and eliminate unnamed literal constants.

**Type annotation requirements**:
- All functions need parameter and return type annotations
- Use `typing.TYPE_CHECKING` for circular dependencies
- Avoid string-based type annotations

**Magic number detection**: Flag literal constants (86400, 3600, 1024). Suggest named constants or enums. Allow well-known literals (0, 1, 2, -1).

**Example finding**:
```
❌ Magic number detected
   src/cache.py:34 - cache.set(key, value, 86400)

   Recommendation: Extract to named constant:
   SECONDS_PER_DAY = 86400  # or: CACHE_TTL = 24 * 60 * 60

❌ Missing type annotations
   src/utils/parser.py:15 - def parse_input(data): return json.loads(data)

   Recommendation: def parse_input(data: str) -> Dict[str, Any]: return json.loads(data)
```

### Check 6: Change Impact Analysis

**Objective**: Validate changes appropriately scoped; justify cross-module impact.

**Check**: Changes limited to target module vs. widespread; cross-module impact with justification; refactoring scope appropriate.

**Scope expectations**:
- Feature addition: 1-3 modules (implementation + tests)
- Bug fix: 1-2 files (bug location + test)
- Refactoring: Broad impact acceptable if explicitly stated
- API change: Multiple files expected, should be documented

**Example finding**:
```
⚠️  Broad change impact
   Changes affect 8 modules across 3 subsystems
   PR title: "Add email validation to User model" but spans multiple subsystems

   Question: Is scope appropriate?
   - If refactoring email validation project-wide: ✅ Document in PR
   - If just adding User.email field: ⚠️ Scope too broad

   Recommendation: Clarify intent and justify cross-module changes

❌ Uncontrolled change scope
   src/config.py:23 - Changed MAX_RETRIES = 3 to 5
   Impact: Affects all modules using MAX_RETRIES

   Recommendation: Document reason, update related tests, consider migration notes if breaking
```

## Integration

### When to Use

Use `/code-review`:
- Before creating pull request
- Before final merge to main
- After milestone commits
- On explicit request

### Integration with Document-Guideline

`document-guideline` defines standards; `review-standard` enforces them.

### Integration with Milestone Workflow

**Milestone commits** (in-progress):
- May bypass linter with `--no-verify`
- Documentation-code inconsistency acceptable
- Review notes progress toward completion

**Delivery commits** (final):
- Must pass all linting without bypass
- Documentation must match implementation
- All tests pass
- Review confirms delivery readiness

### Command Invocation

`/code-review` command:
1. Verifies current branch is not main
2. Gets changed files: `git diff --name-only main...HEAD`
3. Gets full diff: `git diff main...HEAD`
4. Invokes review-standard skill with context
5. Displays formatted report

## Review Report Format

Every review produces structured report with actionable feedback.

### Traceability in Findings

To enable users to quickly locate the specific standard being referenced, every finding **MUST** include an explicit "Standard" line that references the phase and check from this skill document.

**Required format:**
```
❌ Missing interface documentation
   Location: src/utils/validator.py:1
   Standard: Phase 1, Check 3 — Source Code Interface Documentation
   Recommendation: Create validator.md with External Interface section
```

**Key requirements:**
- Use exact phase and check names from section headings in this document
- Format: `Standard: Phase {X}, Check {Y} — {Check Name}`
- Place the Standard line between Location and Recommendation
- Keep the reference concise and human-readable

This approach provides clear traceability without introducing separate registry files or cryptic ID codes.

### Report Structure

```markdown
# Code Review Report

**Branch**: issue-42-feature-name
**Changed files**: 8 files (+450, -120 lines)
**Review date**: 2025-01-15

---

## Phase 1: Documentation Quality

### ✅ Passed
- All folders have README.md files
- Test files have inline documentation

### ❌ Issues Found

#### Missing source interface documentation
- Location: `src/utils/parser.py`
  Standard: Phase 1, Check 3 — Source Code Interface Documentation
  **Recommendation**: Create parser.md with External Interface and Internal Helpers

### ⚠️  Warnings

#### Consider design documentation
- Location: Multiple files (authentication subsystem)
  Standard: Phase 1, Check 5 — Design Documentation
  **Recommendation**: Consider docs/authentication.md for architectural changes spanning 5 files

---

## Phase 2: Code Quality & Reuse

[Similar structure]

---

## Phase 3: Advanced Code Quality

[Similar structure]

---

## Overall Assessment

**Status**: ⚠️  NEEDS CHANGES

**Summary**: 3 critical issues, 3 warnings

**Recommended actions before merge**:
1. Create parser.md documenting interfaces
2. Replace manual JSON validation with existing utility
3. Extract magic number to named constant
4. Add type annotations
5. Consider design doc
6. Evaluate dependency consistency

**Merge readiness**: Not ready - address critical issues first
```

### Assessment Categories

**✅ APPROVED**: All documentation complete, no code quality issues, reuse opportunities addressed, no unnecessary indirection or magic numbers, type annotations present, change scope appropriate. Ready for merge.

**⚠️  NEEDS CHANGES**: Minor documentation gaps, code reuse opportunities exist, non-critical improvements recommended, missing some type annotations, minor magic numbers or scope considerations. Can merge after addressing issues.

**❌ CRITICAL ISSUES**: Missing required documentation, significant code quality problems, major reuse opportunities ignored, unnecessary wrappers hiding design flaws, module responsibility violations, uncontrolled change scope, security or correctness concerns. Must address before merge.

### Providing Actionable Feedback

Every issue must include:
1. **Specific location**: File path and line number
2. **Standard reference**: Phase and check name (e.g., "Phase 1, Check 3 — Source Code Interface Documentation")
3. **Clear problem**: What's wrong and why it matters
4. **Concrete recommendation**: Exact steps to fix
5. **Example**: Code sample or specific implementation (when applicable)

## Summary

The review-standard skill provides systematic code review:
1. **Validates documentation**: Ensures `document-guideline` compliance
2. **Promotes code reuse**: Identifies existing utilities, prevents duplication
3. **Enforces quality**: Checks conventions, patterns, best practices
4. **Provides actionable feedback**: Specific, implementable recommendations

Reviews are recommendations to maintain quality - final merge decisions remain with maintainers.
