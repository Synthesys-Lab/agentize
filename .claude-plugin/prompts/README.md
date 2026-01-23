# Prompts Directory

External template files for workflow continuation prompts. Separating prompt content from code logic improves maintainability and enables easy iteration on prompt text.

## Template Format

Each workflow has a corresponding `.txt` file named after the workflow (e.g., `ultra-planner.txt` for the ultra-planner workflow).

### Variable Syntax

Templates use `{#variable#}` syntax for substitution via Python's `str.replace()`:

| Variable | Description |
|----------|-------------|
| `{#session_id#}` | Current Claude Code session ID for `claude -r` resume |
| `{#fname#}` | Path to handsoff session state JSON file |
| `{#continuations#}` | Current continuation count |
| `{#max_continuations#}` | Maximum continuations allowed |
| `{#pr_no#}` | PR number (used by sync-master workflow) |
| `{#plan_context#}` | Optional plan context (used by issue-to-impl workflow) |

### Why `{#...#}` Instead of `{...}`?

The `{#variable#}` delimiter avoids conflicts with:
- Python format strings (`{variable}`)
- Shell variables (`$variable`, `${variable}`)
- JSON/jq syntax (`{...}`)
- Markdown code blocks containing these syntaxes

## Template Files

| File | Workflow | Purpose |
|------|----------|---------|
| `ultra-planner.txt` | `/ultra-planner` | Multi-agent debate-based planning |
| `issue-to-impl.txt` | `/issue-to-impl` | Complete dev cycle from issue to PR |
| `plan-to-issue.txt` | `/plan-to-issue` | Create GitHub [plan] issues |
| `setup-viewboard.txt` | `/setup-viewboard` | GitHub Projects v2 board setup |
| `sync-master.txt` | `/sync-master` | Sync local main/master with upstream |

## Usage

Templates are loaded by `workflow.py::get_continuation_prompt()` and `workflow.py::_ask_supervisor_for_guidance()`. The public API remains unchanged - callers continue using `get_continuation_prompt(workflow, ...)` without knowing about template files.
