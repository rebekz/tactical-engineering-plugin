# Tactical Engineering

This project implements an approach to planning and executing with AI agents using Claude Code, combined with the Compound Engineering workflow from Every.

## Overview

Based on research from:
- [Claude Sub-Agents Workflow (Full Demo)](https://www.youtube.com/watch?v=-zzbkh9B-5Q) - Ray Fernando
- [IndyDevDan's Skill, Subagent, and Slash Command VSCode Snippets](https://gist.github.com/disler/d9f1285892b9faf573a0699aad70658f)
- [Compound Engineering With Claude Code](https://www.thisisuncharted.co/p/ai-agents-100x-engineers-every)
- [Learning from Every's Compound Engineering](https://lethain.com/everyinc-compound-engineering/)
- [Claude Code Hooks Mastery](https://github.com/disler/claude-code-hooks-mastery)

## Core Concepts

### The Four Compound Engineering Patterns

1. **Plan** - Decouple implementation from research
2. **Work** - Implement the plan
3. **Review** - Review changes against best practices
4. **Compound** - Summarize learnings for future iterations

### Key Workflow Components

- **Plan Mode (Shift+Tab)** - Non-negotiable first step
- **Task System** - TaskCreate, TaskUpdate, TaskList, TaskGet
- **Sub-Agents** - Specialized agents (200K token context each)
- **Skills** - Reusable prompt templates
- **Hooks** - Pre/Post tool execution automation

## Project Structure

```
.claude/
├── agents/           # Sub-agent definitions
├── skills/           # Reusable skills
├── docs/             # Learnings/compound knowledge
└── plan-*.md         # Generated plans
```

## Quick Start

1. Install Claude Code: `npm install -g @anthropic-ai/claude-code`
2. Plan your feature: `/plan_w_team "feature description"`
3. Execute the plan: `/build specs/your-plan.md`
4. Monitor progress: `/status`
5. Validate completion: `/validate specs/your-plan.md`

## Commands

### Planning
- `/plan_w_team` - Create detailed implementation plan with team coordination
- `/plan` - Quick planning mode for simpler features

### Execution
- `/build` - Execute a plan with multi-agent coordination
- `/continue` - Resume an agent with additional work (preserves context)
- `/retry` - Retry a failed task with corrections

### Monitoring
- `/status` - Show status of all tasks and running agents
- `/agents` - List available team members

### Validation
- `/validate` - Run validation commands and check acceptance criteria

## Workflow Example

```
Terminal 1: Frontend agent building UI
Terminal 2: Backend agent creating APIs
Terminal 3: Test agent writing specs
Terminal 4: Docs agent updating guides
You: Orchestrating and reviewing
```

## Sources

- [Claude Sub-Agents Workflow](https://www.youtube.com/watch?v=-zzbkh9B-5Q)
- [IndyDevDan's VSCode Snippets](https://gist.github.com/disler/d9f1285892b9faf573a0699aad70658f)
- [Compound Engineering Article](https://www.thisisuncharted.co/p/ai-agents-100x-engineers-every)
- [Every's Compound Engineering](https://lethain.com/everyinc-compound-engineering/)
- [Claude Code Hooks Mastery](https://github.com/disler/claude-code-hooks-mastery)
- [Claude Code Tasks Guide](https://www.dplooy.com/blog/claude-code-tasks-complete-guide-to-ai-agent-workflow)
