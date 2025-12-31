# Tutorial 03: Advanced Usage - Parallel Development

**Read time: 3-5 minutes**

Scale up development by running multiple AI agents in parallel, each working on different issues simultaneously.

## Choose Your Workflow

**Use clones when:**
- Learning parallel development for the first time
- Working across different machines
- Prefer complete isolation and simpler mental model

**Use worktrees when:**
- Disk space is limited (worktrees share `.git`)
- Working on same machine with multiple terminals
- Want faster setup without re-cloning

Both approaches work identically—pick based on your preference and constraints.

## When to Use Parallel Development

**Good for:**
- Multiple independent features
- Large refactoring split into separate issues
- Documentation updates + feature work
- Bug fixes that don't touch the same files

**Avoid when:**
- Issues modify the same files (high conflict risk)
- Issues have dependencies on each other
- You're new to the framework (start with Tutorial 02 first)

## Approach 1: Repository Clones

### Setup

Create separate clones for each parallel task:

```bash
# Main development directory (already exists)
cd ~/projects

# Create parallel workers
git clone https://github.com/your-org/my-project.git my-project-worker-1
git clone https://github.com/your-org/my-project.git my-project-worker-2
git clone https://github.com/your-org/my-project.git my-project-worker-3
```

### Workflow

Assign one issue per worker clone:

**Terminal 1 (Worker 1 - Issue #45):**
```bash
cd ~/projects/my-project-worker-1
claude-code
# /issue-to-impl 45
```

**Terminal 2 (Worker 2 - Issue #46):**
```bash
cd ~/projects/my-project-worker-2
claude-code
# /issue-to-impl 46
```

**Terminal 3 (Worker 3 - Issue #47):**
```bash
cd ~/projects/my-project-worker-3
claude-code
# /issue-to-impl 47
```

Each AI works independently. Resume milestones in the same clone with `/miles2miles`.

### Cleanup

After merging PRs:

```bash
# Delete worker clones
rm -rf ~/projects/my-project-worker-*

# Or keep them for the next batch
```

## Approach 2: Git Worktrees

Worktrees share the `.git` directory while providing isolated working directories—saves disk space.

### Setup

Use the `wt-cli.sh` script:

```bash
# Create worktree (fetches title from GitHub)
scripts/wt-cli.sh create 42

# Or specify custom description
scripts/wt-cli.sh create 42 add-feature

# Creates: trees/issue-42-add-feature/
# Branch: issue-42-add-feature
```

The script automatically:
- Creates `trees/issue-<N>-<title>/` (gitignored)
- Creates branch following naming convention
- Bootstraps `CLAUDE.md` and `.claude/` into worktree

### Workflow

**Terminal 1 (Issue #45):**
```bash
cd ~/projects/my-project
scripts/wt-cli.sh create 45
cd trees/issue-45-add-rust-support
claude-code
# /issue-to-impl 45
```

**Terminal 2 (Issue #46):**
```bash
cd ~/projects/my-project
scripts/wt-cli.sh create 46
cd trees/issue-46-update-documentation
claude-code
# /issue-to-impl 46
```

Each worktree operates independently on its own branch.

### Important: Path Rules

Each worktree is its own "project root" for path resolution. All paths are relative to the active worktree:
- ✅ `docs/tutorial/03-advanced-usage.md` (relative to worktree root)
- ❌ `../main-repo/docs/...` (crossing worktree boundaries)

The `CLAUDE.md` rule "DO NOT use `cd`" applies within each worktree individually.

### Cleanup

```bash
# Remove specific worktree
scripts/wt-cli.sh remove 42

# List all worktrees
scripts/wt-cli.sh list

# Clean up stale metadata
scripts/wt-cli.sh prune
```

## Managing Progress

### Track Assignments

Keep simple notes on which worker/worktree handles which issue:

```
Worker 1 / trees/issue-45-*: Issue #45 - Rust SDK
Worker 2 / trees/issue-46-*: Issue #46 - Docs update
Worker 3 / trees/issue-47-*: Issue #47 - Performance fix
```

### Resume After Milestones

If a worker creates a milestone, resume in the same location:

```bash
# For clones
cd ~/projects/my-project-worker-1
claude-code
# /miles2miles

# For worktrees
cd ~/projects/my-project/trees/issue-45-*
claude-code
# /miles2miles
```

## Avoiding Conflicts

### Plan for Independence

Design issues to avoid file overlap:
- ✅ Issue #45 modifies `templates/rust/`
- ✅ Issue #46 modifies `docs/`
- ✅ Issue #47 modifies `src/performance.c`

### Stagger Merges

Don't merge all PRs at once:

1. Complete first worker/worktree
   - `/code-review`
   - `/sync-master`
   - Create and merge PR

2. Update others to latest main
   ```bash
   git checkout main
   git pull origin main
   git checkout issue-46-*
   git rebase main
   ```

3. Repeat review and merge for each remaining issue

### Resolve Conflicts

If conflicts occur during rebase:

```bash
git rebase main
# CONFLICT (content): Merge conflict in src/main.c

# Fix in editor, then:
git add src/main.c
git rebase --continue
```

## Best Practices

1. **Limit workers**: 3-4 parallel is manageable, more gets chaotic
2. **Name clearly**: Use descriptive directory/worktree names
3. **Track assignments**: Keep notes on which worker has which issue
4. **Sync before PR**: Always `/sync-master` before creating PRs
5. **Review first**: Always `/code-review` before merge
6. **Start small**: Try 2 parallel issues before scaling up

## When to Use Sequential vs Parallel

**Use sequential (Tutorial 02) when:**
- Learning the framework
- Issues touch the same code
- Issues depend on each other

**Use parallel (this tutorial) when:**
- Issues are independent
- Comfortable with the workflow
- Want to maximize throughput

## Next Steps

You've completed all tutorials! You now know how to:
- ✅ Initialize Agentize (Tutorial 00)
- ✅ Plan issues (Tutorial 01)
- ✅ Implement features (Tutorial 02)
- ✅ Scale with parallel development (Tutorial 03)

Explore the full documentation:
- `.claude/commands/*.md` - All available commands
- `.claude/skills/*/SKILL.md` - How skills work
- `docs/milestone-workflow.md` - Deep dive on milestones
- `README.md` - Architecture and philosophy
