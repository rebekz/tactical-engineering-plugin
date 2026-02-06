# Tactical Engineering

A Claude Code plugin for multi-agent orchestration using the Compound Engineering workflow pattern (Plan, Work, Review, Compound).

## Installation

Inside a Claude Code session, run:

```
/plugin marketplace add https://github.com/rebekz/tactical-engineering-plugin
/plugin install tactical-engineering
```

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
│   ├── party.md           # /party - Full-lifecycle multi-agent product team
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

### From scratch (Party Mode)
1. Install the plugin (see Installation above)
2. Set env: `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
3. Run: `/party "your idea"`
4. Follow the 4-phase workflow: brainstorm, plan, build, validate

### From a spec (Build Mode)
1. Plan your feature: `/plan_w_team "feature description"`
2. Execute the plan: `/build specs/your-plan.md`
3. Monitor progress: `/status`
4. Validate completion: `/validate specs/your-plan.md`
5. Compound learnings: `/compound specs/your-plan.md`

## Commands

### Planning
- `/plan_w_team` - Create detailed implementation plan with team coordination
- `/plan` - Quick planning mode for simpler features

### Full Lifecycle
- `/party` - Run a full product team from idea to implementation (brainstorm, plan, build, validate)

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

## Party Mode

Party mode (`/party`) takes an idea from concept to implementation using a team of 8 specialist agents powered by Claude Agent Teams.

**Phases:**
1. **Brainstorm** - All agents research the topic from their expertise, lead synthesizes findings
2. **Plan** - Agents contribute domain-specific planning, lead assembles a `/build`-compatible spec
3. **Build** - Tasks created from spec, agents self-claim and implement
4. **Validate** - QA validates, Docs writes documentation, DevOps checks deployment readiness

User checkpoints between each phase let you approve, refine, adjust the team, or abort.

**Team Roster:**

| Agent | Role |
|-------|------|
| pm | Product Manager |
| architect | System Architect |
| backend | Backend Developer |
| frontend | Frontend Developer |
| qa | QA Engineer |
| ux | UX Designer |
| docs | Tech Writer |
| devops | DevOps Engineer |

**Prerequisites:**
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

**Usage:**
```bash
/party "Build user authentication with OAuth"
```

### Party vs Build

| | `/party` | `/build` |
|---|----------|----------|
| Input | An idea/topic | A pre-written spec |
| Phases | brainstorm, plan, build, validate | Build only |
| Team | 8 fixed specialists | Defined in spec |
| Output | Spec + implementation + docs | Implementation only |
| Best for | New features from scratch | Implementing existing plans |

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
