# Agents

This directory contains specialized agents for the agentize plugin.

## Overview

Agents are specialized AI subagents invoked by commands via the Task tool with `subagent_type` parameter.

## Naming Convention

- Agents use the `agentize:` prefix when invoked via `subagent_type`
- Mega-planner agents use the `mega-` prefix in their filename to distinguish from ultra-planner agents

## Ultra-Planner Agents (3-agent debate)

| Agent | Role | Philosophy |
|-------|------|------------|
| `bold-proposer` | Generate innovative proposals | Build on existing code, push boundaries |
| `proposal-critique` | Validate single proposal | Challenge assumptions, identify risks |
| `proposal-reducer` | Simplify single proposal | Less is more, eliminate unnecessary complexity |
| `understander` | Gather codebase context | Understand the problem domain |
| `planner-lite` | Quick plans for simple features | Lightweight alternative to full debate |
| `code-quality-reviewer` | Review code quality | Ensure standards compliance |

## Mega-Planner Agents (5-agent debate)

| Agent | Role | Philosophy |
|-------|------|------------|
| `mega-bold-proposer` | Generate innovative proposals with code diffs | Build on existing code, push boundaries |
| `mega-paranoia-proposer` | Generate destructive refactoring proposals | Tear down and rebuild properly |
| `mega-proposal-critique` | Validate BOTH proposals | Challenge assumptions in both, compare |
| `mega-proposal-reducer` | Simplify BOTH proposals | Less is more for both proposals |
| `mega-code-reducer` | Minimize total code footprint | Allow big changes if they shrink codebase |

## Agent Relationships

### Ultra-Planner Flow

```
              +------------------+
              |   understander   |
              +--------+---------+
                       | context
                       v
             +------------------+
             |  bold-proposer   |
             +--------+---------+
                      | proposal
       +--------------+---------------+
       v                              v
+------------------+       +------------------+
|proposal-critique |       |proposal-reducer  |
+------------------+       +------------------+
```

### Mega-Planner Flow

```
              +------------------+
              |   understander   |
              +--------+---------+
                       | context
        +--------------+---------------+
        v                              v
+------------------+       +------------------+
|mega-bold-        |       |mega-paranoia-    |
|proposer          |       |proposer          |
+--------+---------+       +--------+---------+
         |                          |
         +-------------+------------+
                       | both proposals
   +-------------------+-------------------+
   v                   v                   v
+------------+ +---------------+ +------------+
|mega-       | |mega-          | |mega-code-  |
|proposal-   | |proposal-      | |reducer     |
|critique    | |reducer        | |            |
+------------+ +---------------+ +------------+
```

## Usage

**Ultra-planner agents:**
```
subagent_type: "agentize:bold-proposer"
subagent_type: "agentize:proposal-critique"
subagent_type: "agentize:proposal-reducer"
```

**Mega-planner agents:**
```
subagent_type: "agentize:mega-bold-proposer"
subagent_type: "agentize:mega-paranoia-proposer"
subagent_type: "agentize:mega-proposal-critique"
subagent_type: "agentize:mega-proposal-reducer"
subagent_type: "agentize:mega-code-reducer"
```

## See Also

- `/ultra-planner` command: `.claude-plugin/commands/ultra-planner.md`
- `/mega-planner` command: `.claude-plugin/commands/mega-planner.md`
- `external-synthesize` skill: `.claude-plugin/skills/external-synthesize/`
