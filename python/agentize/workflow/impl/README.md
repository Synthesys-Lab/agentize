# Impl Workflow Module

 Python implementation of the `lol impl` issue-to-implementation loop, including
 optional post-PR monitoring for mergeability and CI.

## Organization

- `impl.py` - Workflow orchestration, prompt rendering, and shell invocations
- `continue-prompt.md` - Prompt template for iterative runs
- `__main__.py` - CLI entrypoint for `python -m agentize.workflow.impl`
- `__init__.py` - Public exports for the module
- Companion `.md` files document interfaces and design rationale
