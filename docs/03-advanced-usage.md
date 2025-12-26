# Tutorial 03: Advanced Usage - Parallel Development

**Read time: 3-5 minutes**

This tutorial shows you how to scale up development by running multiple AI agents in parallel.

## The Concept: A Team of AIs

Instead of implementing one issue at a time, you can work on multiple issues simultaneously by:
- Creating multiple clones of your repository
- Assigning each clone a different issue
- Running separate Claude Code sessions in each clone

Think of it as managing a team where each member (AI in a repo clone) works on their own task independently.

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

## Setup: Creating Multiple Working Directories

### Step 1: Clone the Repository Multiple Times

```bash
# Main development directory (already exists)
cd ~/projects/my-project

# Create parallel working directories
cd ~/projects
git clone https://github.com/your-org/my-project.git my-project-worker-1
git clone https://github.com/your-org/my-project.git my-project-worker-2
git clone https://github.com/your-org/my-project.git my-project-worker-3
```

### Step 2: Verify Each Clone

```bash
# Worker 1
cd ~/projects/my-project-worker-1
git branch
# Should show: * main

# Worker 2
cd ~/projects/my-project-worker-2
git branch
# Should show: * main

# Worker 3
cd ~/projects/my-project-worker-3
git branch
# Should show: * main
```

Each clone is independent and can run Claude Code separately.

## Workflow: 3 Issues in Parallel

Let's implement 3 issues simultaneously:
- Issue #45: Add Rust SDK support
- Issue #46: Update documentation
- Issue #47: Fix performance bug

### Assign Issues to Workers

**Terminal 1 (Worker 1 - Issue #45):**
```bash
cd ~/projects/my-project-worker-1
claude-code

# In Claude Code:
/issue-to-impl 45
[... implements Rust SDK support ...]
```

**Terminal 2 (Worker 2 - Issue #46):**
```bash
cd ~/projects/my-project-worker-2
claude-code

# In Claude Code:
/issue-to-impl 46
[... updates documentation ...]
```

**Terminal 3 (Worker 3 - Issue #47):**
```bash
cd ~/projects/my-project-worker-3
claude-code

# In Claude Code:
/issue-to-impl 47
[... fixes performance bug ...]
```

Each AI works independently on its assigned issue.

## Managing Progress

### Track Which Worker is Doing What

Keep a simple note (text file, sticky note, etc.):

```
Worker 1 (~/projects/my-project-worker-1): Issue #45 - Rust SDK
Worker 2 (~/projects/my-project-worker-2): Issue #46 - Docs update
Worker 3 (~/projects/my-project-worker-3): Issue #47 - Performance fix
```

### Resume After Milestones

If a worker creates a milestone, resume in the same clone:

```bash
# Back in Worker 1 terminal
cd ~/projects/my-project-worker-1
claude-code

# In Claude Code:
/miles2miles
[... continues from milestone ...]
```

## Avoiding Conflicts

### Strategy 1: Plan for Independence

When creating issues (Tutorial 01), design them to be independent:
- ✅ Issue #45 modifies `templates/rust/`
- ✅ Issue #46 modifies `docs/`
- ✅ Issue #47 modifies `src/performance.c`

No overlap = no conflicts.

### Strategy 2: Stagger Merges

Don't merge all PRs at once. Instead:

1. Complete Worker 1 (Issue #45)
   - `/code-review`
   - `/sync-master`
   - Ask Claude: "Create a pull request"
   - Merge PR

2. Update Worker 2 and Worker 3
   ```bash
   # In Worker 2
   git checkout main
   git pull origin main

   # In Worker 3
   git checkout main
   git pull origin main
   ```

3. Rebase Worker 2 (Issue #46)
   ```bash
   cd ~/projects/my-project-worker-2
   git checkout issue-46-update-documentation
   git rebase main
   # Resolve any conflicts
   /code-review
   /sync-master
   # Ask Claude: "Create a pull request"
   # Merge PR
   ```

4. Repeat for Worker 3

### Strategy 3: Conflict Resolution

If conflicts do occur during rebase:

```bash
git rebase main
# CONFLICT (content): Merge conflict in src/main.c

# Fix conflicts manually in your editor
vim src/main.c
# Make changes...

# Stage resolved files
git add src/main.c

# Continue rebase
git rebase --continue
```

## Merging Strategy

### Option 1: Sequential Merge (Safest)

```
Issue #45 → Review → Merge → Sync others
Issue #46 → Review → Merge → Sync remaining
Issue #47 → Review → Merge
```

### Option 2: Batch Review (Faster)

```
Issue #45 → Review → Create PR (don't merge yet)
Issue #46 → Review → Create PR (don't merge yet)
Issue #47 → Review → Create PR (don't merge yet)

Review all PRs together
Merge in order: #45 → #46 → #47
```

## Best Practices

1. **Limit workers**: 3-4 parallel workers is manageable, more can be chaotic
2. **Name clones clearly**: Use descriptive directory names (worker-1, worker-2)
3. **Track assignments**: Keep notes on which worker has which issue
4. **Sync frequently**: Run `/sync-master` before creating PRs
5. **Review first**: Always `/code-review` before merge
6. **Start small**: Try 2 parallel issues first before scaling up
7. **Clean up**: Delete worker clones after merging (or keep for next batch)

## Alternative: Git Worktrees for Parallel Development

Git worktrees provide a disk-efficient alternative to cloning the repository multiple times. A worktree shares the `.git` directory with the main repository, saving disk space while providing isolated working directories.

### When to Use Worktrees vs Clones

**Use worktrees when:**
- Disk space is limited (worktrees share the `.git` directory)
- Working on the same machine with multiple terminal sessions
- Want faster setup (no need to re-clone)

**Use clones when:**
- Working across different machines
- Want complete isolation (separate `.git` directories)
- Prefer simpler mental model (each clone is fully independent)

### Setup: Creating Worktrees

Use the helper script to create worktrees:

```bash
# Create worktree with issue number only (fetches title from GitHub)
scripts/worktree.sh create 42

# Create worktree with issue number and custom description
scripts/worktree.sh create 42 add-feature

# Creates: trees/issue-42-add-feature/
# Branch: issue-42-add-feature
```

The script automatically:
- Creates a `trees/issue-<N>-<title>/` directory (gitignored)
- Creates a branch following `issue-<N>-<title>` convention
- Bootstraps `CLAUDE.md` and `.claude/` into the worktree

### List and Remove Worktrees

```bash
# List all worktrees
scripts/worktree.sh list

# Remove a worktree
scripts/worktree.sh remove 42

# Clean up stale worktree metadata
scripts/worktree.sh prune
```

### Workflow: 3 Issues in Parallel with Worktrees

**Terminal 1 (Main repo - Issue #45):**
```bash
cd ~/projects/my-project
scripts/worktree.sh create 45
cd trees/issue-45-add-rust-support
claude-code
# /issue-to-impl 45
```

**Terminal 2 (Worktree - Issue #46):**
```bash
cd ~/projects/my-project
scripts/worktree.sh create 46
cd trees/issue-46-update-documentation
claude-code
# /issue-to-impl 46
```

**Terminal 3 (Worktree - Issue #47):**
```bash
cd ~/projects/my-project
scripts/worktree.sh create 47
cd trees/issue-47-fix-performance-bug
claude-code
# /issue-to-impl 47
```

Each worktree operates independently on its own branch.

### Important: Path Rules with Worktrees

Each worktree is its own "project root" for path resolution. All paths remain relative to the active worktree directory. This means:
- ✅ `docs/03-advanced-usage.md` (relative to worktree root)
- ❌ `../main-repo/docs/...` (crossing worktree boundaries)

The `CLAUDE.md` rule "DO NOT use `cd`" applies within each worktree individually.

### Syncing and Merging with Worktrees

Worktrees share the `.git` directory, so fetches are shared:

```bash
# In any worktree or main repo
git fetch origin

# All worktrees see the updated refs
```

To sync with main before creating a PR:

```bash
# In the worktree
/sync-master
# Or manually:
git fetch origin main:main
git rebase main
```

### Cleanup After Completion

Remove worktrees after merging PRs:

```bash
# Remove specific worktree
scripts/worktree.sh remove 42

# Or manually
git worktree remove trees/issue-42-add-feature

# Clean up stale metadata
git worktree prune
```

Unlike clones, worktrees don't require deleting entire directories—just remove the worktree and git handles cleanup.

## Cleanup After Completion

Once all issues are merged:

**For clones:**
```bash
# Optional: Delete worker clones
rm -rf ~/projects/my-project-worker-1
rm -rf ~/projects/my-project-worker-2
rm -rf ~/projects/my-project-worker-3

# Or keep them for the next batch of issues
```

**For worktrees:**
```bash
# Remove all worktrees
scripts/worktree.sh remove 45
scripts/worktree.sh remove 46
scripts/worktree.sh remove 47

# Prune stale metadata
scripts/worktree.sh prune
```

## Example: Full Parallel Workflow

**Day 1 - Start 3 issues:**
```bash
# Terminal 1
cd ~/projects/my-project-worker-1
claude-code
# /issue-to-impl 45

# Terminal 2
cd ~/projects/my-project-worker-2
claude-code
# /issue-to-impl 46

# Terminal 3
cd ~/projects/my-project-worker-3
claude-code
# /issue-to-impl 47
```

**Day 2 - Resume and complete:**
```bash
# All create milestones, resume next session
# Worker 1: /miles2miles → Complete
# Worker 2: /miles2miles → Complete
# Worker 3: /miles2miles → Complete
```

**Day 3 - Review and merge:**
```bash
# Worker 1
/code-review
/sync-master
User: Create a pull request
# Merge #45

# Update Worker 2 & 3 with main
# Worker 2
/sync-master
/code-review
User: Create a pull request
# Merge #46

# Worker 3
/sync-master
/code-review
User: Create a pull request
# Merge #47
```

## When to Use Sequential vs Parallel

**Use sequential (Tutorial 02) when:**
- Learning the framework
- Issues touch the same code
- Issues depend on each other
- Working alone on a small project

**Use parallel (this tutorial) when:**
- Issues are independent
- Comfortable with the workflow
- Want to maximize throughput
- Have multiple features planned

## Next Steps

You've completed all tutorials! You now know how to:
- ✅ Initialize Agentize (Tutorial 00)
- ✅ Plan issues (Tutorial 01)
- ✅ Implement features (Tutorial 02)
- ✅ Scale with parallel development (Tutorial 03)

Explore the full documentation:
- `claude/commands/*.md` - All available commands
- `claude/skills/*/SKILL.md` - How skills work
- `docs/milestone-workflow.md` - Deep dive on milestones
- `README.md` - Architecture and philosophy
