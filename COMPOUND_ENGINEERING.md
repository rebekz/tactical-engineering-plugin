# Compound Engineering Workflow

This document describes the Compound Engineering workflow from Every, adapted for general use.

## The Four Patterns

### 1. Plan (Decouple Research from Implementation)

Use Plan Mode (Shift+Tab) to research and plan before implementing.

**What to do:**
- Analyze the codebase structure
- Research best practices
- Create detailed implementation plans
- Save plans as `.claude/plan-*.md`

**Commands:**
- `/plan` - Enter plan mode for a feature
- `/plan_w_team` - Plan with specialized agents

### 2. Work (Implement the Plan)

Execute the plan using the task system and agents.

**What to do:**
- Create tasks with `TaskCreate`
- Track progress with `TaskUpdate`
- Use specialized agents for different domains
- Work in parallel across terminals

**Commands:**
- `TaskCreate` - Create a new task
- `TaskUpdate` - Update task status
- `TaskList` - List all tasks
- `TaskGet` - Get task details

### 3. Review (Review Against Best Practices)

Review all changes before committing.

**What to do:**
- Run code review agents
- Check against best practices
- Identify improvements
- Get approval before merging

**Commands:**
- `/review` - Run code review
- `/review:architecture` - Architecture review
- `/review:code-quality` - Code quality review

### 4. Compound (Summarize Learnings)

Document learnings for future iterations.

**What to do:**
- Summarize what worked
- Document what didn't work
- Update best practices
- Feed into future plans

**Commands:**
- `/compound` - Summarize learnings
- `/docs:add` - Add to documentation

## The Compounding Effect

The key insight is that **Compound** feeds back into **Plan**:

```
Plan -> Work -> Review -> Compound -> Plan -> ...
        ^                           |
        |---------------------------|
```

Each task makes the next one faster and more accurate.

## Implementation

See `.claude/skills/` for skill implementations and `.claude/agents/` for agent definitions.

## References

- [Learning from Every's Compound Engineering](https://lethain.com/everyinc-compound-engineering/)
- [Compound Engineering Plugin](https://github.com/EveryInc/compound-engineering-plugin)
