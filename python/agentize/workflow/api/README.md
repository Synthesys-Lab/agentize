# Workflow API Package

Public workflow API for building imperative agent pipelines. This package exposes the Session DSL alongside shared helpers for ACW invocation, prompt rendering, GitHub automation, and path resolution.

## Organization

- `__init__.py` - Convenience re-exports for public API symbols
- `session.py` - Session DSL for running staged workflows (single and parallel)
- `acw.py` - ACW invocation helpers with timing logs and provider validation
- `gh.py` - GitHub CLI wrappers for issue/label/PR actions
- `prompt.py` - Prompt rendering for `{#TOKEN#}` and `{{TOKEN}}` placeholders
- `path.py` - Path resolution helper relative to a module file
- Companion `.md` files document interfaces and internal helpers
