---
title: "Task Persistence - Cross-Session Task State"
date: 2026-02-04
status: brainstorm
type: workflow
tags: [workflow, build, continue, task-management, persistence]
---

# Task Persistence - Cross-Session Task State

## What We're Building

A task persistence system that survives Claude Code session restarts. When `/build` creates tasks, they should be persisted to disk so `/continue-spec` or `/build` can pick them up later—even after closing and reopening Claude Code.

**Current Problem:** TaskList appears to be session-scoped. Tasks disappear when the Claude Code session ends, making `/continue-spec` unable to resume previous builds.

**Desired Behavior:** Tasks created by `/build` persist across sessions, grouped by spec, with full state including agent mappings for resume capability.

## Why This Approach

**Chosen Approach: Per-Spec State Files**

Store task state in `.claude/specs/<spec-name>/state.json` for each spec.

**Why per-spec files:**
- **Isolation** - Each spec has its own state, no conflicts between multiple specs
- **Simple organization** - Easy to find, inspect, debug state for a specific spec
- **Scalable** - Adding new specs doesn't complicate existing state
- **Clean** - State lives alongside the spec it describes
- **Deletable** - Remove a spec's state by deleting its directory

**Why not alternatives:**
- ❌ **Single global file** - Multiple specs would overwrite each other, harder to inspect
- ❌ **Spec-embedded** - Pollutes spec files with execution state, harder to maintain
- ❌ **Export/import** - Requires manual user action, easy to forget

## Key Decisions

### Decision 1: State File Location

**Choice:** `.claude/specs/<sanitized-spec-name>/state.json`

**Structure:**
```
.claude/
└── specs/
    ├── user-authentication/
    │   └── state.json
    ├── checkout-flow/
    │   └── state.json
    └── conversational-ui-revamp/
        └── state.json
```

**Spec name sanitization:**
- Remove `specs/` prefix if present
- Remove `.md` extension
- Replace `/` with `-`
- Example: `specs/user-auth.md` → `user-auth`

**Rationale:**
- Keeps state separate from specs but logically associated
- Easy to programmatically locate state from spec path
- Human-readable for debugging
- Can be deleted without affecting other specs

---

### Decision 2: State File Schema

**Choice:** Comprehensive schema with 4 sections

```json
{
  "build": {
    "specPath": "specs/user-auth.md",
    "specChecksum": "sha256:abc123...",
    "startedAt": "2026-02-04T10:30:00Z",
    "lastUpdated": "2026-02-04T11:45:00Z",
    "totalTasks": 10
  },
  "tasks": [
    {
      "id": "1",
      "subject": "Setup database schema",
      "description": "Create users table with...",
      "status": "completed",
      "activeForm": "Setting up database",
      "blockedBy": [],
      "agentType": "general-purpose"
    },
    {
      "id": "2",
      "subject": "Implement JWT endpoints",
      "description": "Create /auth/login and /auth/refresh...",
      "status": "in-progress",
      "activeForm": "Implementing JWT endpoints",
      "blockedBy": ["1"],
      "agentType": "backend-agent",
      "agentId": "abc123",
      "deployedAt": "2026-02-04T11:00:00Z",
      "lastOutput": "Error: Failed to import jwt..."
    },
    {
      "id": "3",
      "subject": "Build login UI",
      "description": "Create login form with...",
      "status": "pending",
      "activeForm": "Building login UI",
      "blockedBy": ["2"],
      "agentType": "frontend-agent"
    }
  ],
  "artifacts": [
    {
      "taskId": "1",
      "action": "created",
      "path": "db/schema.rb",
      "timestamp": "2026-02-04T10:45:00Z"
    },
    {
      "taskId": "2",
      "action": "modified",
      "path": "app/controllers/auth_controller.rb",
      "timestamp": "2026-02-04T11:15:00Z"
    }
  ],
  "validation": {
    "commandsRun": ["bin/rails test", "bin/rails lint"],
    "acceptanceCriteria": [
      {"criteria": "Users can login with JWT", "status": "passed"},
      {"criteria": "Tokens refresh automatically", "status": "pending"}
    ]
  }
}
```

**Rationale:**
- **build** - Metadata for spec modification detection and build identification
- **tasks** - Core task data with dependencies and agent mappings for resume
- **artifacts** - Track what files were created/modified for each task
- **validation** - Store validation results and acceptance criteria status

---

### Decision 3: Read/Write Strategy

**Write Policy (in /build):**
- Write state file immediately after creating all tasks (Phase 2 complete)
- Update state file on each task status change
- Final write on build completion

**Read Policy (in /continue-spec):**
1. Check if state file exists for spec
2. If exists: Load tasks, validate spec hasn't changed (checksum)
3. If doesn't exist: Fall back to TaskList (for in-progress builds)
4. If both empty: Error "No previous build found"

**Read Policy (in /build resume):**
- Check if state file exists before creating new tasks
- If exists: Ask user "Resume previous build or start fresh?"
- If resume: Load tasks, continue from pending/in-progress state
- If fresh: Delete old state, start new build

**Rationale:**
- State file is source of truth for persisted builds
- TaskList is still primary for active builds (faster, more reliable)
- Graceful fallback when state file missing
- User control over resume vs fresh start

---

### Decision 4: Spec Modification Detection

**Choice:** Store spec checksum in state file, validate on resume

```typescript
// On build start
const specContent = fs.readFileSync(specPath, 'utf8')
const checksum = crypto.createHash('sha256').update(specContent).digest('hex')
state.build.specChecksum = `sha256:${checksum}`

// On resume
const currentChecksum = crypto.createHash('sha256')
  .update(fs.readFileSync(specPath, 'utf8'))
  .digest('hex')

if (state.build.specChecksum !== `sha256:${currentChecksum}`) {
  console.warn("⚠️ Spec modified since last build")
  console.warn("Changes may not be reflected in task definitions")
  // Ask user: continue or restart
}
```

**Rationale:**
- Detects spec changes between sessions
- Prevents using stale task definitions
- User can decide whether to continue or restart

---

### Decision 5: State File Lifecycle

**Creation:**
- Created by `/build` after Phase 2 (all tasks created)
- Directory created if doesn't exist

**Updates:**
- Updated on every task status change
- Updated on agent deployment (store agentId)
- Updated on build completion

**Deletion:**
- **Automatic:** Deleted when `/build --fresh` is run
- **Manual:** User can delete `.claude/specs/<name>/` directory
- **Cleanup:** Consider `/build --cleanup` flag to remove completed builds

**Rationale:**
- State persists until explicitly cleared
- User has control over cleanup
- Fresh builds can start clean

## Open Questions

### Q1: How should /build handle existing state?

**Scenario:** User runs `/build specs/user-auth.md` but `.claude/specs/user-auth/state.json` already exists.

**Options:**
1. **Ask always** - "Resume previous build or start fresh?"
2. **Detect status** - If in-progress, ask; if completed, auto-fresh
3. **Flag required** - Only check state if `--resume` or `--fresh` flag provided

**Recommendation:** Option 2 (smart detection). If previous build is in-progress, offer resume. If completed, auto-start fresh (user can always re-run with intent to resume).

---

### Q2: Should tasks from TaskList be synced to state file?

**Scenario:** `/build` is running, TaskList has in-progress tasks, but state file hasn't been updated recently.

**Options:**
1. **Sync on every TaskUpdate** - State file always matches TaskList (slower)
2. **Sync on milestones** - Only after task completion, phase completion (faster)
3. **Sync on build end** - Only write state when build completes or is interrupted

**Recommendation:** Option 2 (milestone sync). Balance between freshness and performance. Write state after:
- All tasks created (Phase 2 complete)
- Each task completed
- Build interrupted (cleanup handler)

---

### Q3: How to handle concurrent builds on different specs?

**Scenario:** User runs `/build specs/a.md` in one terminal, `/build specs/b.md` in another.

**Options:**
1. **File locking** - Lock state files during writes
2. **Last write wins** - Allow overwrites (simple, works with per-spec isolation)
3. **Detect and warn** - Check for concurrent builds, warn user

**Recommendation:** Option 2 (last write wins). Per-spec isolation means builds don't interfere. If user builds same spec concurrently, that's user error (last write wins is acceptable).

---

### Q4: What happens if state file is corrupted?

**Scenario:** State file exists but has invalid JSON or missing required fields.

**Options:**
1. **Error and bail** - "State file corrupted, run /build --fresh"
2. **Best effort** - Load what we can, warn about corruption
3. **Auto-repair** - Try to reconstruct from TaskList, warn user

**Recommendation:** Option 3 (auto-repair with warning). If TaskList has data, rebuild state from it. If both corrupt, clear error message to re-run build.

---

### Q5: Should state include task outputs?

**Scenario:** Task fails, we want to show error message on resume.

**Options:**
1. **Full output** - Store last N lines of output (can be large)
2. **Last snippet** - Store only last 500 characters
3. **Error only** - Store only error messages
4. **No output** - Use TaskOutput to retrieve from agent if accessible

**Recommendation:** Option 2 (last snippet). Store `lastOutput: string` (500 chars max) in task metadata. Useful for quick inspection, falls back to TaskOutput if agent accessible.

## Integration Points

### /build Command Changes

**Phase 2 (Create Task List):**
```typescript
// After creating all tasks
const state = {
  build: {
    specPath: PATH_TO_PLAN,
    specChecksum: calculateChecksum(PATH_TO_PLAN),
    startedAt: new Date().toISOString(),
    lastUpdated: new Date().toISOString(),
    totalTasks: tasks.length
  },
  tasks: tasks.map(t => ({
    id: t.id,
    subject: t.subject,
    description: t.description,
    status: t.status,
    activeForm: t.activeForm,
    blockedBy: t.blockedBy || [],
    agentType: t.agentType
  })),
  artifacts: [],
  validation: { commandsRun: [], acceptanceCriteria: [] }
}

writeStateFile(PATH_TO_PLAN, state)
```

**During execution:**
```typescript
// On task status change
await TaskUpdate({ taskId: "1", status: "completed" })
updateTaskInState(PATH_TO_PLAN, "1", { status: "completed" })

// On agent deployment
const result = await Task({ ... })
updateTaskInState(PATH_TO_PLAN, taskId, {
  agentId: result.agentId,
  deployedAt: new Date().toISOString()
})
```

**On completion:**
```typescript
// Final state update
state.build.lastUpdated = new Date().toISOString()
writeStateFile(PATH_TO_PLAN, state)
```

---

### /continue-spec Command Changes

**Detection Phase:**
```typescript
// Try to load state file first
const state = loadStateFile(SPEC_PATH)

if (state) {
  // Validate spec hasn't changed
  const currentChecksum = calculateChecksum(SPEC_PATH)
  if (state.build.specChecksum !== currentChecksum) {
    // Warn about spec modification
  }

  // Load tasks from state
  const tasks = state.tasks
  const completed = tasks.filter(t => t.status === 'completed')
  const inProgress = tasks.filter(t => t.status === 'in-progress')
  const pending = tasks.filter(t => t.status === 'pending')
} else {
  // Fall back to TaskList
  const tasks = await TaskList({})
  // ... existing logic
}
```

**Task Execution:**
```typescript
// Use agentId from state for resume
const agentId = taskDetails.agentId
if (agentId && isAgentAccessible(agentId)) {
  await Task({
    resume: agentId,
    ...
  })
}
```

---

### /build Resume Capability

**New flag: `--resume`**

```typescript
// Check for existing state
const state = loadStateFile(PATH_TO_PLAN)

if (state && !FLAGS.fresh) {
  const action = await AskUserQuestion({
    question: "Previous build found. What would you like to do?",
    options: [
      { label: "Resume", description: "Continue from where we left off" },
      { label: "Fresh", description: "Start over from beginning" }
    ]
  })

  if (action === "Resume") {
    // Load tasks, continue execution
    const pending = state.tasks.filter(t => t.status !== 'completed')
    // ... continue with pending tasks
  } else {
    // Delete state, start fresh
    deleteStateFile(PATH_TO_PLAN)
  }
}
```

## Next Steps

1. **Run `/workflows:plan`** - Create implementation plan for task persistence
2. **Define file I/O helpers** - Functions for reading/writing state files
3. **Implement in /build** - Add state file creation and updates
4. **Implement in /continue-spec** - Load from state file, fallback to TaskList
5. **Add --resume flag** - Enable /build to resume its own work
6. **Test cross-session** - Verify state survives Claude Code restart

## Related Brainstorms

- `/continue` Command: `docs/brainstorms/2026-02-04-continue-command-brainstorm.md`
- `/compound` Command: `docs/brainstorms/2026-02-03-compound-command-brainstorm.md`

## Related Commands

- `/build` - Creates tasks, should write state file
- `/continue-spec` - Resumes tasks, should read state file
- `/status` - Should display state file information

## References

- Current /build command: `.claude/commands/build.md`
- Current /continue-spec command: `.claude/commands/continue-spec.md`
- Task persistence issue: Tasks disappear between sessions
