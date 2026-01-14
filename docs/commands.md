# Commands

This document describes the command definitions for Claude Code. Commands are shortcuts that can be invoked to execute specific workflows or skills.

## Purpose

Commands provide a simple interface to invoke complex workflows or skills. Each command is defined in a markdown file with frontmatter metadata in the `.claude-plugin/commands/` directory.

## Configuration

Command files include:
- `name`: The command name (used for invocation)
- `description`: Brief description of what the command does
- Instructions on how to use the command and which skills it invokes

## Available Commands

### Git & GitHub

- `git-commit`: Invokes the commit-msg skill to create commits with meaningful messages following project standards
- `pull-request`: Review code changes and optionally create a pull request with --open flag
- `sync-master`: Synchronizes local main/master branch with upstream (or origin) using rebase

### Code Review

- `agent-review`: Review code changes via agent with isolated context and Opus model
- `code-review`: Review code changes from current HEAD to main/HEAD following review standards

### Planning & Implementation

- `make-a-plan`: Creates comprehensive implementation plans following design-first TDD approach
- `plan-an-issue`: Create GitHub [plan] issues from implementation plans with proper formatting
- `issue-to-impl`: Orchestrates full implementation workflow from issue to completion (creates branch, docs, tests, and first milestone)
- `ultra-planner`: Multi-agent debate-based planning with /ultra-planner command (supports --refine mode for iterative improvement)

### Project Setup

- `setup-viewboard`: Set up a GitHub Projects v2 board with agentize-compatible Status fields, labels, and automation workflows
