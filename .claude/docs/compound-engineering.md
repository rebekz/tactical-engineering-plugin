# Compound Engineering Learnings

This document contains learnings from implementing compound engineering workflows.

## Overview

Compound Engineering consists of four patterns:

1. **Plan** - Decouple implementation from research
2. **Work** - Implement the plan
3. **Review** - Review against best practices
4. **Compound** - Summarize learnings for future

## Key Insights

### The Compounding Effect

The key insight is that **Compound** feeds back into **Plan**:

```
Plan -> Work -> Review -> Compound -> Plan -> ...
        ^                           |
        |---------------------------|
```

Each task makes the next one faster and more accurate.

### Fix Problems at the Lowest Value Stage

Don't let AI implement a flawed plan. Review the architecture early when changes are cheap.

### Build Prompts That Build Prompts

Create prompts that generate research documents, which become prompts for implementation.

## Workflow Commands

- `/workflows:plan` - Turn ideas into implementation plans
- `/workflows:work` - Execute the plan
- `/workflows:review` - Multi-agent code review
- `/workflows:compound` - Combine all workflows

## References

- [Claude Code Docs - Common Workflows](https://code.claude.com/docs/en/common-workflows)
- [DevGenius Blog - Plan Work Review Compound Method](https://blog.devgenius.io/claude-code-the-proven-plan-work-review-compound-method-cbf07c24ae85)
- [Learning from Every's Compound Engineering](https://lethain.com/everyinc-compound-engineering/)
