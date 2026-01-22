# Mega-Planner Agents

This directory contains specialized agents for the mega-planner multi-agent debate system.

## Overview

The mega-planner uses a dual-proposer architecture where two agents with opposing philosophies generate proposals, which are then analyzed by critique and reducer agents.

## Agents

| Agent | Role | Philosophy |
|-------|------|------------|
| `bold-proposer` | Generate innovative proposals | Build on existing code, push boundaries |
| `paranoia-proposer` | Generate destructive refactoring proposals | Tear down and rebuild properly |
| `proposal-critique` | Validate both proposals | Challenge assumptions, identify risks |
| `proposal-reducer` | Simplify both proposals | Less is more, eliminate unnecessary complexity |
| `code-reducer` | Minimize total code footprint | Allow big changes if they shrink codebase |

## Agent Relationships

```
                    ┌─────────────────┐
                    │  understander   │ (external)
                    └────────┬────────┘
                             │ context
              ┌──────────────┴──────────────┐
              ▼                             ▼
    ┌─────────────────┐           ┌─────────────────┐
    │  bold-proposer  │           │paranoia-proposer│
    └────────┬────────┘           └────────┬────────┘
             │                             │
             └──────────────┬──────────────┘
                            │ both proposals
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│proposal-critique│ │proposal-reducer │ │  code-reducer   │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

## Usage

These agents are invoked by the `/mega-planner` command using the `mega-planner:` prefix:

```
subagent_type: "mega-planner:bold-proposer"
subagent_type: "mega-planner:paranoia-proposer"
subagent_type: "mega-planner:proposal-critique"
subagent_type: "mega-planner:proposal-reducer"
subagent_type: "mega-planner:code-reducer"
```

## See Also

- `/mega-planner` command: `.claude/commands/mega-planner.md`
- `partial-consensus` skill: `.claude/skills/partial-consensus/`
