---
title: Agent Teams Support for /build Command
date: 2026-02-06
status: ready
tags: [agent-teams, orchestration, build-command]
---

# Agent Teams Support for /build Command

## What We're Building

Add a `--team` flag to the `/build` command that uses Claude Code's native Agent Teams (TeamCreate, SendMessage, delegate mode) instead of subagents (Task tool) for plan execution. The default remains subagents for backward compatibility. Start with `/build` only; expand to `/compound` later based on results.

## Why This Approach

### Current State (Subagents)

- `/build` uses `Task` tool with `run_in_background: true` to spawn workers
- Workers report results back to the lead but **cannot talk to each other**
- Lead manually monitors via `TaskOutput` and coordinates sequentially
- Good for independent, focused tasks

### Agent Teams Advantage

- Teammates are full independent Claude Code sessions
- Teammates can **message each other** via `SendMessage` (e.g., frontend tells backend about API contract changes)
- **Shared task list** with self-claiming - teammates pick up unblocked work automatically
- **Delegate mode** prevents lead from implementing directly
- **Plan approval** - can require teammates to plan before coding
- **Split panes** - visual monitoring of all teammates in tmux/iTerm2

### Trade-offs

| Aspect | Subagents (default) | Agent Teams (--team) |
|--------|-------------------|---------------------|
| Token cost | Lower | Higher (each teammate = full session) |
| Communication | One-way (worker → lead) | Multi-directional (any → any) |
| Task claiming | Lead assigns explicitly | Self-claiming + lead assignment |
| Best for | Independent, focused tasks | Cross-cutting work needing coordination |
| Requires | Nothing extra | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |

## Key Decisions

1. **Flag-based opt-in**: `/build specs/plan.md --team` activates agent team mode; default is subagent mode
2. **Start with /build only**: Scope limited to `/build` command initially
3. **Backward compatible**: Existing subagent behavior unchanged without `--team` flag
4. **Delegate mode**: When `--team` is used, the lead enters delegate mode (coordination only, no direct coding)
5. **Plan approval**: Teammates required to plan before implementing (configurable in spec)

## Implementation Sketch

### /build --team Mode Changes

```
Phase 1: Parse & Prepare (same as current)
Phase 2: Create Team
  - TeamCreate({ team_name: "<spec-name>", description: "Build: <spec>" })
  - Create shared task list via TaskCreate (same as current)
Phase 3: Spawn Teammates
  - For each team member in spec:
    Task({ team_name, name: "<role>", subagent_type: "<type>", mode: "plan" })
  - Enter delegate mode (Shift+Tab equivalent)
Phase 4: Assign Tasks
  - TaskUpdate with owner for each task → teammate name
  - Teammates self-claim unblocked tasks as they finish
Phase 5: Monitor & Coordinate
  - Messages arrive automatically (no polling needed)
  - Lead synthesizes findings, resolves conflicts via SendMessage
Phase 6: Shutdown & Cleanup
  - SendMessage type: "shutdown_request" to each teammate
  - TeamDelete to clean up
```

### Spec Format Changes

Team Members section in plan specs would map to actual Agent Team roles:

```markdown
### Team Members

#### Builder: backend-api
- **Agent Type:** backend-agent
- **Model:** opus
- **Plan Approval:** true

#### Builder: frontend-ui
- **Agent Type:** frontend-agent
- **Model:** sonnet
- **Plan Approval:** false
```

## Open Questions

1. **State persistence**: Current state-file.js tracks subagent IDs. Agent Teams use teammate names. Need unified state tracking?
2. **Resume across sessions**: Agent Teams don't support session resumption well (documented limitation). How does this interact with `/continue-spec`?
3. **Error recovery**: If a teammate crashes, should the lead auto-spawn a replacement or ask the user?
4. **File conflicts**: Need to ensure spec's task assignments avoid multiple teammates editing the same files

## Prerequisites

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` must be enabled
- tmux recommended for split-pane visibility (optional)

## Next Steps

Run `/workflows:plan` to create implementation spec for the `--team` flag on `/build`.
