---
title: "feat: Add --team Flag to /build Command for Agent Teams Support"
type: feat
date: 2026-02-06
---

# feat: Add --team Flag to /build Command for Agent Teams Support

## Overview

Add a `--team` flag to the `/build` command that uses Claude Code's native Agent Teams (`TeamCreate`, `SendMessage`, delegate mode) instead of subagents (`Task` tool) for plan execution. The default remains subagent mode for backward compatibility. This enables multi-directional teammate communication, self-claiming task assignment, and delegate-mode orchestration for complex, cross-cutting builds.

## Problem Statement / Motivation

The current `/build` command deploys subagents via `Task` tool with `run_in_background: true`. This works well for independent, focused tasks but has limitations:

- **One-way communication**: Workers report back to the lead but cannot talk to each other
- **Lead bottleneck**: The lead manually monitors via `TaskOutput` and coordinates sequentially
- **No self-claiming**: The lead must explicitly assign every task

Agent Teams solve these by providing:
- **Multi-directional communication**: Any teammate can message any other (e.g., frontend notifies backend about API contract changes)
- **Shared task list with self-claiming**: Teammates pick up unblocked work automatically
- **Delegate mode**: Lead coordinates without implementing directly
- **Plan approval**: Teammates can be required to plan before coding

## Proposed Solution

Add a `--team` flag that branches the `/build` command's execution phases into team-mode equivalents while preserving all existing subagent behavior as the default.

### High-Level Flow

```
/build specs/plan.md --team
  ├── Phase 0: Resume Detection (detects team-mode state)
  ├── Phase 1: Parse & Prepare (same as current)
  ├── Phase 2: Prerequisites Check (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
  ├── Phase 3: Create Tasks + TeamCreate
  ├── Phase 4: Set Dependencies (same as current)
  ├── Phase 5: Spawn Teammates + Assign Initial Tasks
  ├── Phase 6: Monitor via Messages (no polling)
  ├── Phase 6.5: Per-Task Validation Hooks
  ├── Phase 7: Validation Commands (same as current)
  └── Phase 8: Shutdown & Cleanup (SendMessage shutdown_request + TeamDelete)
```

## Technical Approach

### State File Schema Extension

**File:** `scripts/state-file.js`

Add these fields to support team mode. Subagent-mode state files are unchanged.

```json
{
  "build": {
    "specPath": "specs/plan.md",
    "specChecksum": "sha256:...",
    "startedAt": "ISO",
    "lastUpdated": "ISO",
    "totalTasks": 10,
    "mode": "team",
    "teamName": "plan-name"
  },
  "tasks": [
    {
      "id": "1",
      "subject": "Build auth API",
      "status": "in-progress",
      "agentType": "backend-agent",
      "agentId": null,
      "teammateName": "backend-api",
      "deployedAt": "ISO",
      "lastOutput": "..."
    }
  ],
  "artifacts": [],
  "validation": {}
}
```

**New fields:**
- `build.mode`: `"subagent"` (default) or `"team"` - determines which execution path to use
- `build.teamName`: Name used for `TeamCreate` - derived from `sanitizeSpecName()`
- `tasks[].teammateName`: The teammate name that owns this task (team mode only)

**Changes to `state-file.js`:**

```javascript
// scripts/state-file.js

// Add mode to writeStateFile default build object
function createInitialState(specPath, tasks, mode = "subagent") {
  return {
    build: {
      specPath,
      specChecksum: calculateChecksum(specPath),
      startedAt: new Date().toISOString(),
      lastUpdated: new Date().toISOString(),
      totalTasks: tasks.length,
      mode,                                    // NEW
      teamName: mode === "team"                // NEW
        ? sanitizeSpecName(specPath)
        : null
    },
    tasks: tasks.map(t => ({
      ...t,
      agentId: null,
      teammateName: null                       // NEW
    })),
    artifacts: [],
    validation: {}
  }
}

// Extend updateTaskInState to accept teammateName
function updateTaskInState(specPath, taskId, updates) {
  // ... existing logic ...
  // `updates` can now include { teammateName: "backend-api" }
}
```

### Phase-by-Phase Implementation

#### Phase 0: Resume Detection (Modified)

**Current behavior:** Reads state file, asks Resume/Fresh if in-progress tasks exist.

**Team-mode additions:**
1. Read state file as normal
2. If state exists and `build.mode === "team"`:
   - Check for orphaned team resources at `~/.claude/teams/{teamName}/`
   - If team resources exist, offer: "Previous team build found. Resume remaining tasks / Start fresh (cleanup) / Abort"
   - If "Start fresh", call `TeamDelete` + `deleteStateFile()`
   - If "Resume", filter to pending + in-progress tasks, proceed to Phase 3
3. **Mixed-mode detection:** If state exists with `build.mode === "subagent"` but user passed `--team` (or vice versa):
   - Warn: "Previous build used [subagent/team] mode. Current invocation uses [team/subagent] mode."
   - Offer: "Continue with [current mode] (honors completed tasks) / Start completely fresh / Abort"
   - If continuing, honor completed task statuses but use current mode for remaining tasks

#### Phase 2: Prerequisites Check (New for --team)

```
if (TEAM_MODE) {
  // Check for Agent Teams experimental flag
  const envCheck = Bash("echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS")
  if (envCheck !== "1") {
    REPORT: "Agent Teams requires the experimental flag. Enable it with:"
    REPORT: "  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
    REPORT: "Then restart Claude Code and retry."
    STOP
  }
}
```

#### Phase 3: Create Tasks + TeamCreate (Modified)

**Current behavior:** `TaskCreate` for all tasks, then `writeStateFile()`.

**Team-mode additions:**
```
// After TaskCreate for all tasks...

if (TEAM_MODE) {
  const teamName = sanitizeSpecName(PATH_TO_PLAN)

  // Check for existing team (orphaned from previous build)
  // TeamCreate will fail if team already exists
  try {
    TeamCreate({
      team_name: teamName,
      description: `Build: ${specTitle}`
    })
  } catch (error) {
    // Team already exists - ask user
    AskUserQuestion: "Team '{teamName}' already exists. Delete and recreate? / Abort"
    if (recreate) {
      TeamDelete()  // Clean up existing
      TeamCreate({ team_name: teamName, description: `Build: ${specTitle}` })
    }
  }

  writeStateFile(PATH_TO_PLAN, state, "team")
}
```

#### Phase 5: Spawn Teammates + Assign Tasks (Modified)

**Current subagent behavior:** Deploy one agent per task via `Task({ run_in_background })`.

**Team-mode behavior:**
```
if (TEAM_MODE) {
  // 1. Spawn one teammate per unique team member defined in spec
  const teamMembers = parseTeamMembers(specContent)

  // Confirmation prompt with cost awareness
  AskUserQuestion: "About to spawn {teamMembers.length} teammates. Each is a full Claude session. Proceed? / Abort"

  for (const member of teamMembers) {
    Task({
      team_name: teamName,
      name: member.name,                    // e.g., "backend-api"
      subagent_type: member.agentType,      // e.g., "backend-agent"
      mode: member.planApproval ? "plan" : "default",
      model: member.model || "opus",
      prompt: `You are ${member.name}, a teammate on the "${teamName}" team.
Your role: ${member.role}

## Your Tasks
Check the shared task list with TaskList. Claim unassigned, unblocked tasks
by setting yourself as owner with TaskUpdate({ taskId, owner: "${member.name}" }).
Prefer tasks in ID order.

After completing each task:
1. Mark it completed: TaskUpdate({ taskId, status: "completed" })
2. Send the lead a completion message via SendMessage with a summary of what you did
3. Check TaskList for your next available task
4. If no more tasks, send the lead a message saying you're done

## Coordination
- Message the lead for blockers or questions
- Message other teammates directly if you need to coordinate on shared interfaces
- Read the team config at ~/.claude/teams/${teamName}/config.json to find teammate names`
    })
  }

  // 2. Assign initial batch of tasks (unblocked tasks)
  for (const task of unblockedTasks) {
    const assignee = findAssignee(task, teamMembers)  // From spec's "Assigned To" field
    TaskUpdate({
      taskId: task.id,
      owner: assignee.name,
      status: "in_progress"
    })
    updateTaskInState(PATH_TO_PLAN, task.id, {
      status: "in-progress",
      teammateName: assignee.name,
      deployedAt: new Date().toISOString()
    })
  }

  // 3. Remaining tasks are left for self-claiming as they become unblocked
}
```

#### Phase 6: Monitor via Messages (Modified)

**Current subagent behavior:** Poll via `TaskOutput` with `block: true/false`.

**Team-mode behavior:**
```
if (TEAM_MODE) {
  // Messages arrive automatically from teammates - no polling needed
  // The lead's role is to:

  // 1. Process completion messages
  //    - When a teammate reports task completion:
  //      a. Capture the output from the message content
  //      b. Update state: updateTaskInState(specPath, taskId, { status: "completed", lastOutput })
  //      c. Run validation hooks (Phase 6.5) using the message content as agentOutput
  //      d. Mark task completed: TaskUpdate({ taskId, status: "completed" })

  // 2. Handle plan approval requests (if any teammate has Plan Approval: true)
  //    - Teammate sends plan_approval_request
  //    - Lead reviews the plan
  //    - SendMessage({ type: "plan_approval_response", recipient, approve: true/false })

  // 3. Resolve conflicts and blockers
  //    - If a teammate reports a blocker, the lead:
  //      a. Assesses the situation
  //      b. Either resolves it or asks the user via AskUserQuestion
  //      c. Sends resolution to teammate via SendMessage

  // 4. Track progress
  //    - Periodically check TaskList to see overall progress
  //    - All tasks completed → proceed to Phase 7

  // 5. Detect stalled teammates
  //    - If a teammate has been in_progress for an unusually long time with no messages:
  //      a. Send a check-in message: SendMessage({ recipient: teammateName, content: "Status update?" })
  //      b. If no response after check-in, ask user:
  //         AskUserQuestion: "Teammate '{name}' is unresponsive. Respawn replacement / Skip task / Wait longer"
  //      c. If respawn: spawn new teammate, assign the stalled task to it
}
```

#### Phase 6.5: Per-Task Validation Hooks (Modified)

**Current behavior:** Uses `TaskOutput` result as `context.agentOutput` for hook validation.

**Team-mode adaptation:**
```
if (TEAM_MODE) {
  // Use the teammate's completion message content as agentOutput
  const agentOutput = completionMessage.content
  const hooks = extractTaskHooks(specContent, task.subject)
  const result = runHooks(hooks.stop, { ...context, agentOutput })
  // ... same validation logic as subagent mode ...
}
```

#### Phase 8: Shutdown & Cleanup (New for --team)

```
if (TEAM_MODE) {
  // 1. Request shutdown for each teammate
  for (const member of teamMembers) {
    SendMessage({
      type: "shutdown_request",
      recipient: member.name,
      content: "Build complete. Shutting down."
    })
  }

  // 2. Wait briefly for shutdown acknowledgments
  // Teammates should respond with shutdown_response { approve: true }
  // If a teammate doesn't respond within 30 seconds, proceed anyway

  // 3. Clean up team resources
  TeamDelete()

  // 4. Update state file
  updateTaskInState(PATH_TO_PLAN, null, {
    "build.completedAt": new Date().toISOString()
  })
}
```

### /build Command Changes

**File:** `commands/build.md`

**Frontmatter changes:**
```yaml
---
name: build
description: Execute a plan document from specs/ directory with multi-agent coordination.
argument-hint: [path-to-plan] [--team]
model: opus
allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, NotebookEdit, WebFetch, WebSearch, AskUserQuestion, Skill, TodoWrite, TeamCreate, TeamDelete, SendMessage
---
```

**Variables section addition:**
```markdown
## Variables
- `PATH_TO_PLAN`: $1 - Path to the plan document in specs/
- `TEAM_MODE`: --team - Use Agent Teams instead of subagents for execution
```

**Early flag detection:**
```markdown
## Mode Detection

Parse arguments:
- If `--team` is present in arguments, set `TEAM_MODE = true`
- Otherwise, `TEAM_MODE = false`

If `TEAM_MODE`:
  - Run Prerequisites Check (Phase 2)
  - All subsequent phases use team-mode branches as documented above
```

### /continue-spec Changes

**File:** `commands/continue-spec.md`

**Auto-detect mode from state file** (no `--team` flag needed on `/continue-spec`):

```markdown
## Mode Detection

After reading state file:
- If `state.build.mode === "team"`:
  - Agent Teams do not support session resumption
  - Create a fresh team with TeamCreate
  - Filter task list to pending + failed tasks only
  - Spawn teammates for remaining work
  - Assign remaining tasks
- If `state.build.mode === "subagent"` (or undefined for legacy state files):
  - Use existing subagent resume logic (unchanged)
```

**Key behavior for team-mode resume:**
1. Read state file, get `teamName` and remaining tasks
2. Check for orphaned team resources, clean up if found
3. `TeamCreate` with same `teamName`
4. Spawn teammates (same member definitions from spec)
5. Only assign pending/in-progress tasks (skip completed ones)
6. Monitor via messages (same as Phase 6)

### /status Command Changes

**File:** `commands/status.md`

Add team-mode awareness:
```markdown
## Team Mode Detection

If state file has `build.mode === "team"`:
  - Read team config at `~/.claude/teams/{teamName}/config.json`
  - Display teammate names, their current task, and status
  - Show message count if available
  - Example output:

  ## Team: plan-name
  | Teammate | Current Task | Status |
  |----------|-------------|--------|
  | backend-api | Task 3: Build auth API | Working |
  | frontend-ui | Task 5: Create login form | Working |
  | test-runner | (idle) | Waiting for tasks |
```

### Spec Format (Backward Compatible)

**No changes required to `/plan_w_team`** for MVP. The existing Team Members format works:

```markdown
### Team Members

#### Builder
- **Name:** backend-api
- **Role:** backend
- **Agent Type:** backend-agent
- **Resume:** true
```

**Optional new fields** (gracefully ignored if absent):
```markdown
#### Builder
- **Name:** backend-api
- **Role:** backend
- **Agent Type:** backend-agent
- **Model:** opus
- **Plan Approval:** true
- **Resume:** true
```

Defaults if omitted: `Model: opus`, `Plan Approval: false`.

### Commands That Are OUT OF SCOPE

Per the brainstorm decision "Start with `/build` only":

- `/retry` - Left unchanged. If used during a team build, it deploys a subagent (acceptable for single-task retry)
- `/continue` (single agent) - Left unchanged. Not applicable to team mode
- `/compound` - Left unchanged. Reads from state file and TaskList, which are populated correctly by team mode
- `/validate` - Left unchanged. Runs spec validation commands regardless of build mode

## Acceptance Criteria

### Functional Requirements

- [ ] `/build specs/plan.md --team` creates an Agent Team and executes the plan using teammates
- [ ] `/build specs/plan.md` (no flag) works exactly as before (subagent mode)
- [ ] State file includes `build.mode` and `build.teamName` for team-mode builds
- [ ] Each task in state file has `teammateName` field for team-mode builds
- [ ] Prerequisites check blocks `--team` if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is not set
- [ ] Team is cleaned up (`TeamDelete`) after successful build completion
- [ ] Orphaned team resources are detected and cleaned up on fresh `--team` builds
- [ ] `/continue-spec` auto-detects team mode from state file and creates fresh team for remaining tasks
- [ ] `/status` shows teammate information for team-mode builds
- [ ] Mixed-mode detection warns user when state file mode differs from current invocation
- [ ] Teammates can message each other directly for coordination
- [ ] Teammates self-claim unblocked tasks after completing their initial assignment
- [ ] Completion message from teammate is captured as `agentOutput` for validation hooks

### Quality Gates

- [ ] Existing `/build` tests (if any) pass without modification
- [ ] State file schema is backward compatible (old state files still work)
- [ ] All path references use `$CLAUDE_PLUGIN_ROOT`

## Step by Step Tasks

### 1. Extend State File Schema for Team Mode
- **Task ID:** team-001
- **Depends On:** none
- **Assigned To:** backend-agent
- **Agent Type:** backend-agent
- **Parallel:** true
- **Files:** `scripts/state-file.js`
- Add `mode` and `teamName` fields to `build` object in state schema
- Add `teammateName` field to task entries
- Add `createInitialState(specPath, tasks, mode)` helper function
- Ensure `readStateFile` handles both old (no mode field) and new state files gracefully
- Ensure `updateTaskInState` accepts `teammateName` in updates
- Ensure `rebuildStateFromTaskList` includes `teammateName: null` in rebuilt entries
- **Acceptance Criteria:**
  - `writeStateFile` with `mode: "team"` produces correct JSON
  - `readStateFile` on old state files (no `mode`) returns `mode: "subagent"` as default
  - `updateTaskInState` can set `teammateName` on individual tasks

### 2. Add --team Flag Parsing and Prerequisites Check to /build
- **Task ID:** team-002
- **Depends On:** none
- **Assigned To:** backend-agent
- **Agent Type:** backend-agent
- **Parallel:** true
- **Files:** `commands/build.md`
- Add `TEAM_MODE: --team` to Variables section
- Add `TeamCreate, TeamDelete, SendMessage` to allowed-tools in frontmatter
- Add `argument-hint: [path-to-plan] [--team]` to frontmatter
- Add Mode Detection section after Variables
- Add Prerequisites Check phase that verifies `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- **Acceptance Criteria:**
  - `--team` flag is parsed from arguments
  - Build aborts with clear message if env var not set when `--team` is used
  - Without `--team`, all behavior is unchanged

### 3. Implement Team-Mode Resume Detection (Phase 0)
- **Task ID:** team-003
- **Depends On:** team-001
- **Assigned To:** backend-agent
- **Agent Type:** backend-agent
- **Parallel:** false
- **Files:** `commands/build.md`
- Modify Phase 0 to check `state.build.mode` when state file exists
- Add orphaned team resource detection (check `~/.claude/teams/{teamName}/`)
- Add mixed-mode detection and warning with user prompt
- Add "Resume remaining tasks / Start fresh / Abort" options for team-mode state
- Handle `TeamDelete` cleanup when starting fresh
- **Acceptance Criteria:**
  - Team-mode state file triggers team-mode resume flow
  - Orphaned team resources are detected and user is prompted
  - Mixed-mode warning shown when state mode differs from `--team` flag

### 4. Implement Team Creation and Teammate Spawning (Phases 3+5)
- **Task ID:** team-004
- **Depends On:** team-002, team-003
- **Assigned To:** backend-agent
- **Agent Type:** backend-agent
- **Parallel:** false
- **Files:** `commands/build.md`
- After TaskCreate phase, add `TeamCreate` call with sanitized spec name
- Handle team name collision (existing team from previous incomplete build)
- Parse team members from spec's `### Team Members` section
- Add cost confirmation prompt showing teammate count
- Spawn each teammate via `Task({ team_name, name, subagent_type, mode, model })`
- Write teammate prompt with: role description, task claiming instructions, coordination guidelines
- Assign initial batch of unblocked tasks via `TaskUpdate({ owner: teammateName })`
- Update state file with `teammateName` for each assigned task
- **Acceptance Criteria:**
  - `TeamCreate` is called with correct team name
  - Each unique team member from spec is spawned as a teammate
  - Teammates receive clear instructions about task claiming and communication
  - Initial unblocked tasks are assigned to correct teammates
  - State file reflects team name and teammate assignments

### 5. Implement Message-Based Monitoring (Phase 6)
- **Task ID:** team-005
- **Depends On:** team-004
- **Assigned To:** backend-agent
- **Agent Type:** backend-agent
- **Parallel:** false
- **Files:** `commands/build.md`
- Replace `TaskOutput` polling with message-based monitoring for team mode
- Process teammate completion messages: update state, capture output for validation
- Handle plan approval requests from teammates with `plan_mode_required`
- Handle blocker messages from teammates (assess and resolve or escalate to user)
- Implement stalled teammate detection: check-in message after inactivity, user prompt for unresponsive
- Track overall progress via `TaskList` and trigger completion when all tasks done
- **Acceptance Criteria:**
  - Lead processes completion messages and updates state file
  - Plan approval requests are handled correctly
  - Stalled teammate detection triggers user prompt
  - Build completes when all tasks are done

### 6. Adapt Validation Hooks for Team Mode (Phase 6.5)
- **Task ID:** team-006
- **Depends On:** team-005
- **Assigned To:** backend-agent
- **Agent Type:** backend-agent
- **Parallel:** false
- **Files:** `commands/build.md`
- Use teammate completion message content as `context.agentOutput` for validation hooks
- Run same `extractTaskHooks` + `runHooks` logic as subagent mode
- Handle validation failure: send retry instruction to teammate via `SendMessage`
- **Acceptance Criteria:**
  - Validation hooks receive teammate message content as agent output
  - Failed validation triggers retry message to teammate
  - Validation results written to state file

### 7. Implement Shutdown and Cleanup (Phase 8)
- **Task ID:** team-007
- **Depends On:** team-005
- **Assigned To:** backend-agent
- **Agent Type:** backend-agent
- **Parallel:** false
- **Files:** `commands/build.md`
- Send `shutdown_request` to each teammate after build completion
- Handle shutdown_response (approve/reject)
- Add timeout: proceed with `TeamDelete` after 30 seconds if no response
- Call `TeamDelete` to clean up team resources
- Update state file with completion timestamp
- **Acceptance Criteria:**
  - All teammates receive shutdown request
  - Team resources cleaned up via `TeamDelete`
  - State file updated with completion timestamp

### 8. Update /continue-spec for Team-Mode Auto-Detection
- **Task ID:** team-008
- **Depends On:** team-001
- **Assigned To:** backend-agent
- **Agent Type:** backend-agent
- **Parallel:** true
- **Files:** `commands/continue-spec.md`
- Add mode detection from state file `build.mode` field
- For `mode === "team"`: create fresh team, spawn teammates, assign remaining tasks only
- Clean up orphaned team resources before creating new team
- Skip agent resume logic (Agent Teams don't support session resumption)
- Use message-based monitoring for team-mode continuation
- **Acceptance Criteria:**
  - `/continue-spec` auto-detects team mode from state file
  - Fresh team is created for team-mode continuation (no session resume)
  - Only pending and failed tasks are assigned
  - Completed tasks are honored from previous build

### 9. Update /status for Team-Mode Display
- **Task ID:** team-009
- **Depends On:** team-001
- **Assigned To:** frontend-agent
- **Agent Type:** frontend-agent
- **Parallel:** true
- **Files:** `commands/status.md`
- Add team-mode detection from state file
- Read team config at `~/.claude/teams/{teamName}/config.json` for teammate info
- Display teammate table with name, current task, and status
- Show build mode indicator (subagent/team) in status header
- **Acceptance Criteria:**
  - `/status` shows team information for team-mode builds
  - Teammate names and their assigned tasks are visible
  - Build mode is clearly indicated

### 10. Update COMMANDS.md Documentation
- **Task ID:** team-010
- **Depends On:** team-004, team-008, team-009
- **Assigned To:** docs-agent
- **Agent Type:** docs-agent
- **Parallel:** false
- **Files:** `COMMANDS.md`
- Document the `--team` flag for `/build`
- Document auto-detection behavior in `/continue-spec`
- Document team-mode display in `/status`
- Add prerequisites section about `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Add trade-offs table (subagent vs team mode)
- **Acceptance Criteria:**
  - All new behaviors are documented
  - Prerequisites clearly stated
  - Examples included for common workflows

## Team Orchestration

### Team Members

#### Builder: backend-agent
- **Name:** backend-agent
- **Role:** backend
- **Agent Type:** backend-agent
- **Resume:** true

#### Builder: frontend-agent
- **Name:** frontend-agent
- **Role:** frontend
- **Agent Type:** frontend-agent
- **Resume:** true

#### Builder: docs-agent
- **Name:** docs-agent
- **Role:** documentation
- **Agent Type:** docs-agent
- **Resume:** true

## Dependencies & Risks

### Dependencies
- Claude Code Agent Teams feature (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) must be available
- Agent Teams API (`TeamCreate`, `SendMessage`, `TeamDelete`) must be stable

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Agent Teams API changes (experimental) | Medium | High | Pin to known working behavior, add version check |
| Teammate crash with no notification | Medium | Medium | Stalled detection with timeout + user prompt |
| Team name collision from incomplete builds | Low | Medium | Orphaned resource detection + cleanup |
| File conflicts between teammates | Medium | Medium | Spec design responsibility (documented in plan) |
| Token cost surprise for users | High | Low | Cost confirmation prompt before spawning |

## Open Questions Resolved

| Question | Resolution |
|----------|-----------|
| State persistence: subagent IDs vs teammate names | Both fields in state schema. `agentId` for subagent mode, `teammateName` for team mode. `build.mode` determines which to use. |
| Resume across sessions | `/continue-spec` auto-detects mode from state file. Team mode creates fresh team with remaining tasks (no session resume). |
| Error recovery for crashed teammates | Stalled detection (check-in message) + user prompt: Respawn / Skip / Wait. |
| File conflicts | Plan responsibility. Documented as a best practice in spec format. Not enforced by tooling in MVP. |
| Delegate mode | Advisory only. The `/build` command instructions tell the lead to coordinate, not implement. Not enforced at tool level (tools remain in allowed-tools). |
| `/continue-spec` needs `--team`? | No. Auto-detects from state file `build.mode`. |
| `/retry` during team build | Left as-is. Deploys subagent for single-task retry (acceptable hybrid). |
| `/compound` after team build | Works unchanged. Reads from state file and TaskList. |
| Plan approval | Opt-in per teammate via `Plan Approval: true` in spec. Default: false. |
| Teammate model | Opt-in per teammate via `Model: opus/sonnet` in spec. Default: opus. |

## References & Research

### Internal References
- Brainstorm: `docs/brainstorms/2026-02-06-agent-teams-support-brainstorm.md`
- Current build command: `commands/build.md`
- State management: `scripts/state-file.js`
- Continue-spec: `commands/continue-spec.md`
- Status command: `commands/status.md`
- Hook system: `scripts/hooks.js`
- CLAUDE.md conventions: `CLAUDE.md`

### External References
- Claude Code Agent Teams: https://code.claude.com/docs/en/agent-teams
- Claude Code experimental flags documentation
