- When writing any scripts, **AVOID** being shell-specific.
  - The most common thing I can foresee is that `BASH_SOURCE[0]` or `$0` between zsh and bash to get the current script name.

## Path Variables: AGENTIZE_HOME vs PROJECT_ROOT

Scripts in this SDK use two distinct path resolution mechanisms:

**AGENTIZE_HOME** (Static, from `setup.sh`)
- Exported by `setup.sh` as an absolute path to the agentize SDK installation
- Used for referencing agentize SDK assets (scripts, templates, `.claude/` configs)
- Example: `source "$AGENTIZE_HOME/scripts/wt-cli.sh"`
- Set once during `make setup`, persists across shell sessions

**PROJECT_ROOT** (Dynamic, git-based)
- Resolved at runtime via `git rev-parse --git-common-dir` (see `wt_resolve_repo_root()` in `scripts/wt-cli.sh`)
- Used when operating on user repositories or worktrees
- Works correctly inside linked worktrees (resolves to main repo root, not worktree path)
- Example: `git -C "$repo_root" worktree add ...`

**When to use each:**
- Use `AGENTIZE_HOME` for SDK-internal operations (sourcing libraries, accessing templates)
- Use git-based resolution (`wt_resolve_repo_root`) for project-specific operations (worktree management, repo queries)
- Avoid `$0` / `BASH_SOURCE[0]` for path resolution in cross-shell contexts
