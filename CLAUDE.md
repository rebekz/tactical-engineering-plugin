# Multi-Agent Development Workflow - Agent Guidelines

Guidelines for AI agents working in this multi-agent orchestration system.

## Overview

This project uses a multi-agent orchestration workflow inspired by IndyDevDan and Every's Compound Engineering. The focus is on orchestration over implementation - becoming a conductor rather than a typist.

## Architecture Patterns

### Orchestration First

**Principle:** Use agents to execute work, don't implement directly.

- Use Task tool to deploy agents
- Use TaskList and TaskGet to track progress
- Use TaskOutput to monitor agent execution
- Resume agents with preserved context for follow-up work

**Correct:**
```typescript
// Deploy agent to do the work
const agent = Task({
  description: "Build authentication system",
  prompt: "Create JWT auth endpoints...",
  subagent_type: "general-purpose",
  run_in_background: true
})

// Later, resume same agent with preserved context
Task({
  description: "Continue authentication",
  prompt: "Now add refresh tokens...",
  subagent_type: "general-purpose",
  resume: agent.agentId  // Critical: preserves context
})
```

**Incorrect:**
```
// Writing code directly without agents
// Misses the point of the orchestration system
```

---

### Multi-Agent Coordination

**Principle:** Multiple agents can work in parallel when tasks are independent.

- Use `run_in_background: true` for parallel execution
- Use TaskOutput with `block: false` for non-blocking checks
- Wait for dependent agents with `block: true`

**Example:**
```typescript
// Launch frontend and backend agents in parallel
const frontendAgent = Task({
  description: "Build UI",
  subagent_type: "frontend-agent",
  run_in_background: true
})

const backendAgent = Task({
  description: "Build API",
  subagent_type: "backend-agent",
  run_in_background: true
})

// Both work in parallel...
// Wait for frontend
TaskOutput({ task_id: frontendAgent.agentId, block: true })

// Wait for backend
TaskOutput({ task_id: backendAgent.agentId, block: true })

// Integration test depends on both
Task({
  description: "Integration test",
  subagent_type: "test-agent",
  run_in_background: false  // Sequential
})
```

---

## Documentation Patterns

### Compounding Knowledge

**Principle:** Each unit of work should make subsequent units easier.

After completing builds, run `/compound` to document:
- Architecture decisions (ADRs in docs/adr/)
- Mistakes and solutions (docs/solutions/)
- Deployment learnings (docs/deployment.md)
- Reusable patterns (CLAUDE.md)

**When to Compound:**
- After significant features are built
- After solving difficult problems
- After making architectural decisions
- Before forgetting what was learned

---

### Plan-First Development

**Principle:** Always create a plan before building.

1. Run `/plan` or `/plan_w_team` to create a spec
2. Review the plan with the team
3. Run `/build` to execute the plan with multi-agent coordination
4. Run `/compound` to document learnings

**Never skip the planning step** - it ensures alignment and saves time.

---

## Implementation Patterns

### Command Structure

Follow the established pattern from `.claude/commands/`:

```yaml
---
name: command-name
description: Brief description
argument-hint: [optional-argument]
model: opus
allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, AskUserQuestion, Skill
---

# Command Name

## Variables
- `VAR`: Description

## Instructions
...

## Workflow
...

## Report
```

### Agent Structure

Follow the established pattern from `.claude/agents/`:

```yaml
---
name: agent-name
description: Brief description
tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, AskUserQuestion, Skill
model: opus
permissionMode: default
skills:
  - workflow:work
color: purple
---

# Agent Name

## Purpose
<what this agent does>

## Instructions
<step-by-step instructions>

## Workflow
<process flow>

## Report
<output format>
```

---

## Quality Standards

### Code Quality

- Follow existing code patterns in the codebase
- Match naming conventions exactly
- Write tests for new functionality
- Run tests after changes

### Documentation Quality

- Update plan document checkboxes as tasks complete
- Keep documentation synchronized with code
- Use clear, concise language
- Include examples for complex concepts

### Commit Quality

- Use incremental commits for logical units
- Write conventional commit messages
- Don't create "WIP" commits
- Group related changes into single commits

---

## Common Patterns

### Reading Codebases

**For exploration:**
- Use Task tool with Explore subagent for codebase exploration
- Use Glob to find files by pattern
- Use Grep to search for patterns
- Use Read to understand specific files

**For implementation:**
- Read existing patterns before creating new code
- Match the style and structure of existing code
- Reuse existing components where possible
- Don't reinvent patterns

---

### Error Handling

**When an agent fails:**
1. Read the error message from TaskOutput
2. Assess the cause (code error, missing dependency, unclear requirements?)
3. Choose action: Retry, Adjust prompt, or Skip
4. Document the resolution

**Recovery pattern:**
```typescript
// First attempt
Task({
  description: "Build API",
  prompt: "Create REST API endpoints...",
  subagent_type: "backend-agent"
})
// Returns with error about missing dependency

// Resume with correction
Task({
  description: "Build API - with dependency fix",
  prompt: "Add the missing dependency first, then create endpoints...",
  subagent_type: "backend-agent",
  resume: previousAgentId  // Preserve context
})
```

---

## Growth Mindset

### Continuous Learning

- Document what you learn so others benefit
- Read documentation before implementing
- Ask questions when uncertain
- Share knowledge with the team

### Iteration Over Perfection

- Ship complete features, not perfect features
- Iterate based on feedback
- Focus on delivering value
- Improve incrementally

---

**Last Updated:** 2026-02-03
**Status:** Initial version
