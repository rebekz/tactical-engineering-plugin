# Commands Reference

This document describes all available commands for the multi-agent development workflow.

## Planning Commands

### `/plan_w_team`

Create detailed implementation plans with team coordination.

**Usage:**
```bash
/plan_w_team "Feature description"
```

**With orchestration:**
```bash
/plan_w_team "Build real-time chat" "Use frontend-agent for UI, backend-agent for API. Run in parallel."
```

**Output:** Creates `specs/<feature-name>.md` with:
- Task breakdown with dependencies
- Team member assignments
- Implementation phases
- Acceptance criteria
- Validation commands

### `/plan`

Quick planning mode for simpler features.

**Usage:**
```bash
/plan "Add user authentication"
```

## Execution Commands

### `/build`

Execute a plan with multi-agent coordination.

**Usage:**
```bash
/build specs/conversational-ui-revamp.md
```

**What it does:**
1. Parses the plan document
2. Creates tasks in the shared task list
3. Sets up task dependencies
4. Deploys agents for each task
5. Monitors progress
6. Handles parallel/sequential execution

**Example output:**
```
🔄 Build Progress

Phase 1: Foundation
✅ Task 1: Setup database
🔄 Task 2: Create migrations

Phase 2: Core Implementation
⏳ Task 3: Build frontend (waiting)
⏳ Task 4: Build backend (waiting)
```

### `/continue`

Resume an agent with additional work (preserves context).

**Usage:**
```bash
/continue <agent-id> "Add input validation to endpoints"
```

**When to use:**
- Adding work to an in-progress task
- Refining what an agent has built
- Follow-up changes to completed work

**Example:**
```bash
/continue abc123 "Add error handling to all endpoints"
```

### `/retry`

Retry a failed task with corrected instructions.

**Usage:**
```bash
/retry <task-id> "The endpoint needs query parameters, not body params"
```

**When to use:**
- Agent failed with code errors
- Wrong approach was taken
- Requirements need clarification

## Monitoring Commands

### `/status`

Show status of all tasks and running agents.

**Usage:**
```bash
/status          # Show all tasks
/status --pending # Show only pending tasks
/status --active # Show only in-progress tasks
```

**Example output:**
```
📋 Task Status

Pending Tasks:
- [5] Build UI components

In Progress:
- [2] Create migrations (assigned to: builder-db)
  Status: Creating tables...

Completed:
- [1] Setup database ✅

Blocked:
- [3] Build API (blocked by: 2)
```

### `/agents`

List all available team members.

**Usage:**
```bash
/agents
```

**Example output:**
```
🤖 Available Team Members

General Purpose:
- general-purpose - Default agent for general tasks

Specialized Agents:
- frontend-agent - Builds UI components and views
  Role: Frontend Implementation
  Type: frontend-agent

- backend-agent - Creates APIs and business logic
  Role: Backend Implementation
  Type: backend-agent
```

## Validation Commands

### `/validate`

Run validation commands and check acceptance criteria.

**Usage:**
```bash
/validate specs/conversational-ui-revamp.md
```

**What it does:**
1. Runs all validation commands from the plan
2. Checks acceptance criteria
3. Compiles results into a report

**Example output:**
```
🔍 Validation Report

Plan: specs/conversational-ui-revamp.md

Validation Commands:
✅ npm run test
✅ npm run lint
❌ npm run build - TypeScript errors found

Acceptance Criteria:
Functional Requirements:
✅ F1: User can start conversations
✅ F2: User can ask follow-up questions
⏳ F3: User can search conversations (manual verification)

Non-Functional Requirements:
✅ NF1: First insight < 3s (measured: 2.1s)
❌ NF2: Reconnect < 5s (measured: 7.3s, target: 5s)

Overall Status: PARTIAL

Issues:
- TypeScript errors in ChatContainer.tsx
- SSE reconnection too slow
```

## Workflow Example

Complete workflow for a feature:

```bash
# 1. Plan the feature
/plan_w_team "Add real-time notifications"

# 2. Review the plan
cat specs/real-time-notifications.md

# 3. Execute the plan
/build specs/real-time-notifications.md

# 4. Monitor progress (in another terminal)
/status

# 5. If an agent fails, retry with correction
/retry 7 "Use WebSocket instead of polling"

# 6. Add more work to in-progress task
/continue abc123 "Add notification sounds"

# 7. When complete, validate
/validate specs/real-time-notifications.md
```

## Parallel Execution Example

```bash
# Terminal 1: Start the build
/build specs/conversational-ui.md

# Terminal 2: Monitor status
/watch --interval 5 /status

# Terminal 3: Watch logs
tail -f logs/*.log
```

## Tips

1. **Always plan first** - Use `/plan_w_team` before starting implementation
2. **Monitor progress** - Use `/status` to track what's happening
3. **Resume when possible** - Use `/continue` to preserve agent context
4. **Validate at the end** - Use `/validate` to ensure quality
5. **Read the plan** - Review the generated plan before building
