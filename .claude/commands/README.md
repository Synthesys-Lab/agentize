# Commands

This directory contains custom slash commands for Claude Code.

## Available Commands

| Command | Description |
|---------|-------------|
| `/mega-planner` | Multi-agent debate-based planning with dual proposers |
| `/sibyl` | Alias for `/mega-planner` |

## Usage

Invoke commands with arguments:

```
/mega-planner Add user authentication with JWT tokens
/mega-planner --refine 42 Add rate limiting
/mega-planner --from-issue 42
/mega-planner --resolve 42 1B,2A
```

## See Also

- Agents: `.claude/agents/`
- Skills: `.claude/skills/`
