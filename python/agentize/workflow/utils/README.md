# Workflow Utils Package

Shared helpers for workflow orchestration, covering ACW invocation, GitHub CLI actions,
prompt rendering, and path resolution.

## Organization

- `__init__.py` - Convenience re-exports for public helper APIs
- `acw.py` - ACW invocation helpers with timing logs and provider validation
- `gh.py` - GitHub CLI wrappers for issue/label/PR actions
- `prompt.py` - Prompt rendering for `{#TOKEN#}` and `{{TOKEN}}` placeholders
- `path.py` - Path resolution helper relative to a module file
- Companion `.md` files document interfaces and internal helpers
