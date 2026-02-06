# Tactical Engineering

A Claude Code plugin for multi-agent orchestration using the Compound Engineering workflow pattern (Plan, Work, Review, Compound).

## Installation

```bash
# Install as a Claude Code plugin
claude plugin add /path/to/tactical-engineering-plugin

# Or clone and install from GitHub
git clone https://github.com/rebekz/tactical-engineering-plugin.git
claude plugin add ./tactical-engineering-plugin
```

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/build-with-claude/claude-code/overview) CLI installed
- [Node.js](https://nodejs.org/) (for helper scripts)
- [uv](https://docs.astral.sh/uv/) (for Python hook validators, optional)

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

## Plugin Structure

```
tactical-engineering-plugin/
├── .claude-plugin/
│   └── plugin.json        # Plugin manifest
├── commands/              # Slash commands
│   ├── build.md           # /build - Execute plans with multi-agent coordination
│   ├── compound.md        # /compound - Extract and document learnings
│   ├── plan-w-team.md     # /plan_w_team - Create implementation plans
│   ├── continue.md        # /continue - Resume agent with context
│   ├── continue-spec.md   # /continue-spec - Resume from spec state
│   ├── retry.md           # /retry - Retry failed tasks
│   ├── validate.md        # /validate - Check acceptance criteria
│   ├── status.md          # /status - Monitor task progress
│   └── agents.md          # /agents - List team members
├── agents/                # Specialized sub-agents
│   ├── context-gatherer.md
│   ├── code-reviewer.md
│   ├── backend-agent.md
│   ├── frontend-agent.md
│   ├── test-agent.md
│   ├── docs-agent.md
│   ├── task-planner.md
│   ├── task-analyzer-agent.md
│   ├── architecture-writer-agent.md
│   ├── claude-updater-agent.md
│   ├── deployment-writer-agent.md
│   ├── doc-assembler-agent.md
│   └── mistake-extractor-agent.md
├── skills/                # Auto-activating skills
│   ├── work/SKILL.md      # Implement plans
│   ├── plan/SKILL.md      # Create plans
│   ├── review/SKILL.md    # Review changes
│   ├── compound/SKILL.md  # Compound learnings
│   └── zai-cli/SKILL.md   # Z.AI CLI integration
├── hooks/                 # Event-driven automation
│   ├── hooks.json         # Hook configuration
│   └── validators/        # Python validation scripts
├── scripts/               # Node.js helper utilities
│   ├── state-file.js      # Build state persistence
│   └── hooks.js           # Validation hook helpers
└── docs/                  # Reference documentation
```

## Quick Start

1. Install the plugin (see Installation above)
2. Plan your feature: `/plan_w_team "feature description"`
3. Execute the plan: `/build specs/your-plan.md`
4. Monitor progress: `/status`
5. Validate completion: `/validate specs/your-plan.md`
6. Compound learnings: `/compound specs/your-plan.md`

## Commands

### Planning
- `/plan_w_team` - Create detailed implementation plan with team coordination
- `/plan` - Quick planning mode for simpler features

### Execution
- `/build` - Execute a plan with multi-agent coordination
- `/continue` - Resume an agent with additional work (preserves context)
- `/continue-spec` - Resume a build from saved state across sessions
- `/retry` - Retry a failed task with corrections

### Monitoring
- `/status` - Show status of all tasks and running agents
- `/agents` - List available team members

### Validation & Knowledge
- `/validate` - Run validation commands and check acceptance criteria
- `/compound` - Extract and document learnings from completed builds

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
