---
title: "Continue Spec Resume - Resume Work from Spec File"
type: feat
date: 2026-02-04
status: ready
---

# Plan: Continue Spec Resume Command

## Overview

A `/continue` command variant that resumes work from a spec file, intelligently detecting which tasks are complete and which remain. Unlike `/continue <agent-id>` (resumes one specific agent), this command resumes the **entire build workflow** from a spec.

## Problem Statement

When `/build` is interrupted (user cancels, error occurs, session times out):
- Some tasks may be completed
- Some tasks may be in-progress
- Some tasks may be pending
- Agents may or may not still be accessible

**Current limitations:**
- Re-running entire `/build` wastes completed work
- Manually resuming each agent is tedious and error-prone
- No way to "pick up where we left off"
- Lost agent context on interruption

## Proposed Solution

Create a smart resume command that:
1. Detects current state from TaskList (source of truth)
2. Continues from where work stopped
3. Handles failures gracefully with user input
4. Preserves agent context when possible
5. Provides clear progress feedback
6. Prompts for `/compound` on completion

## Technical Approach

### Architecture

The command follows this detection and execution flow:

```
┌─────────────────────────────────────────────────────────────┐
│  1. DETECTION PHASE                                        │
│  - Read spec file                                           │
│  - Get TaskList state                                       │
│  - Categorize: completed/in-progress/pending                │
│  - Check for edge cases (spec changed, agents lost)           │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  2. IN-PROGRESS HANDLING                                   │
│  - If tasks are in-progress, show last output               │
│  - Ask user: Resume / Restart / Skip                        │
│  - Take action based on user choice                         │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  3. PENDING TASK EXECUTION                                │
│  - Sort pending tasks by dependencies (blockedBy)            │
│  - For each task:                                           │
│    - Check if agent exists in task metadata                  │
│    - If exists & accessible → Resume with context           │
│    - If not → Fresh deployment                              │
│    - Update task metadata with agentId                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  4. COMPLETION                                             │
│  - All tasks complete                                       │
│  - Show completion summary                                  │
│  - Prompt for /compound                                     │
└─────────────────────────────────────────────────────────────┘
```

### State Detection Strategy

**Use TaskList as Source of Truth:**

```typescript
// 1. Read all tasks
const allTasks = await TaskList({})

// 2. Categorize by status
const completed = allTasks.filter(t => t.status === 'completed')
const inProgress = allTasks.filter(t => t.status === 'in_progress')
const pending = allTasks.filter(t => t.status === 'pending')

// 3. Edge case: No task state
if (allTasks.length === 0) {
  return {
    error: 'no_task_state',
    message: 'No previous build found. Run /build first.',
    suggestion: '/build specs/feature-name.md'
  }
}
```

**Why TaskList instead of spec parsing:**
- TaskList is authoritative for execution state
- Spec checkboxes may be stale (not updated if build crashed)
- TaskList contains dependency info (`blockedBy`)
- TaskList has owner assignments
- TaskList metadata can store agentId mappings

### Agent Resume Strategy

**Hybrid Approach - Resume when possible, fresh when not:**

```typescript
for (const task of pendingTasks) {
  const taskDetails = await TaskGet({ taskId: task.id })
  const agentId = taskDetails.metadata?.agentId

  if (agentId && isAgentAccessible(agentId)) {
    // Resume existing agent (preserves context!)
    await Task({
      description: taskDetails.subject,
      prompt: buildPromptFromSpec(taskDetails, specContent),
      subagent_type: taskDetails.agentType || 'general-purpose',
      resume: agentId
    })
  } else {
    // Fresh deployment
    const result = await Task({
      description: taskDetails.subject,
      prompt: buildPromptFromSpec(taskDetails, specContent),
      subagent_type: taskDetails.agentType || 'general-purpose',
      run_in_background: false
    })

    // Store agentId for future resume
    await TaskUpdate({
      taskId: task.id,
      metadata: {
        agentId: result.agentId,
        deployedAt: new Date().toISOString()
      }
    })
  }
}

function isAgentAccessible(agentId) {
  try {
    await TaskOutput({
      task_id: agentId,
      block: false,
      timeout: 1000
    })
    return true
  } catch {
    return false
  }
}
```

### In-Progress Task Handling

**Investigate and ask user before proceeding:**

```typescript
const inProgressTasks = allTasks.filter(t => t.status === 'in_progress')

if (inProgressTasks.length > 0) {
  console.log(`⚠️ Found ${inProgressTasks.length} in-progress task(s)`)

  for (const task of inProgressTasks) {
    const agentId = task.metadata?.agentId

    if (agentId) {
      const output = await TaskOutput({
        task_id: agentId,
        block: false,
        timeout: 5000
      })

      console.log(`\nTask: ${task.subject}`)
      console.log(`Status: ${task.status}`)
      console.log(`Last output: ${output.slice(0, 500)}...`)
    }

    const action = await AskUserQuestion({
      question: `Task "${task.subject}" is in-progress. What should we do?`,
      options: [
        {
          label: "Resume",
          description: "Continue from where agent left off (preserves context)"
        },
        {
          label: "Restart",
          description: "Start this task over from beginning (fresh agent)"
        },
        {
          label: "Skip",
          description: "Mark as completed and move on to next task"
        }
      ]
    })

    // Handle user choice...
  }
}
```

### Edge Case Handling

| Edge Case | Detection | Handling |
|-----------|-----------|----------|
| **Spec never built** | TaskList returns empty tasks | Error: "No previous build found. Run `/build` first." |
| **No task state** | TaskList error or empty | Suggest `/build` or ask if spec was modified externally |
| **Spec changed** | Compare spec mtime with earliest task creation | Warning: "Spec modified since last build. Changes may not be reflected in ongoing tasks." |
| **Agents lost** | TaskOutput fails or timeout | Info: "Agent no longer accessible, starting fresh deployment" |

### Spec Modification Detection

```typescript
// Detect if spec was modified since build started
const specMtime = fs.statSync(specPath).mtimeMs

// Find earliest task creation time
const tasks = await TaskList({})
if (tasks.length > 0) {
  const taskCreated = await Promise.all(
    tasks.map(t => getTaskCreatedAt(t.id))
  )
  const earliestTask = Math.min(...taskCreated)

  if (specMtime > earliestTask) {
    console.warn("⚠️ Spec modified since last build.")
    console.warn("Changes may not be reflected in ongoing tasks.")

    const proceed = await AskUserQuestion({
      question: "Spec has been modified. Continue anyway?",
      options: [
        { label: "Continue", description: "Proceed with current task state" },
        { label: "Restart build", description: "Run /build to pick up new spec changes" }
      ]
    })

    if (proceed === 'restart') {
      // Suggest running /build
      return { suggestion: 'Run /build to start fresh with updated spec' }
    }
  }
}
```

## Acceptance Criteria

### Functional Requirements

- [ ] FR1: Command accepts spec path as argument: `/continue specs/feature.md`
- [ ] FR2: Command detects task state from TaskList
- [ ] FR3: Command categorizes tasks as completed/in-progress/pending
- [ ] FR4: Command resumes accessible agents with preserved context
- [ ] FR5: Command deploys fresh agents when resume not possible
- [ ] FR6: Command stores agentId in task metadata for future resume
- [ ] FR7: Command handles in-progress tasks with user prompt
- [ ] FR8: Command respects task dependencies (blockedBy)
- [ ] FR9: Command updates spec checkboxes as tasks complete
- [ ] FR10: Command prompts for `/compound` on completion
- [ ] FR11: Command supports `--dry-run` flag
- [ ] FR12: Command supports `--from-task N` flag to start from specific task
- [ ] FR13: Command supports `--restart` flag to ignore completed tasks

### Edge Case Handling

- [ ] EC1: Handles spec never built (empty TaskList)
- [ ] EC2: Handles no task state (TaskList error)
- [ ] EC3: Detects and warns about spec modifications
- [ ] EC4: Handles lost/inaccessible agents gracefully
- [ ] EC5: Handles in-progress tasks with user choice

### Non-Functional Requirements

- [ ] NFR1: Command completes detection in <5 seconds
- [ ] NFR2: Command provides clear progress feedback
- [ ] NFR3: Command preserves agent context when possible
- [ ] NFR4: Command integrates cleanly with existing /build workflow
- [ ] NFR5: Command follows existing /continue <agent-id> patterns

## Implementation Phases

### Phase 1: Foundation

**File:** `.claude/commands/continue-spec.md`

**Tasks:**
1. Create command with YAML frontmatter and basic structure
2. Implement spec path validation
3. Implement TaskList reading and categorization
4. Add basic error handling (spec not found, empty TaskList)
5. Implement state detection logic
6. Add dry-run mode

**Success Criteria:**
- Command detects task state correctly
- Edge cases return appropriate errors
- Dry-run shows what would be done without executing

### Phase 2: In-Progress Handling

**Tasks:**
1. Implement in-progress task detection
2. Add TaskOutput retrieval for in-progress tasks
3. Implement AskUserQuestion flow for Resume/Restart/Skip
4. Handle each user choice appropriately
5. Test with simulated in-progress scenarios

**Success Criteria:**
- In-progress tasks are detected and shown to user
- User choice is captured and executed
- Resume works with existing agentId
- Restart marks task as pending for fresh deployment
- Skip marks task as completed

### Phase 3: Task Execution

**Tasks:**
1. Implement pending task sorting by dependencies (blockedBy)
2. Implement buildPromptFromSpec function
3. Implement agent accessibility check
4. Implement hybrid resume/fresh deploy logic
5. Store agentId in task metadata on deployment
6. Update spec checkboxes as tasks complete
7. Implement progress reporting

**Success Criteria:**
- Pending tasks execute in dependency order
- Agents are resumed when accessible
- Fresh agents deployed when needed
- AgentIds stored for future resume
- Spec checkboxes stay in sync

### Phase 4: Edge Cases & Flags

**Tasks:**
1. Implement spec modification detection
2. Add `--from-task N` flag support
3. Add `--restart` flag support
4. Implement all 4 edge case handlers
5. Add comprehensive error messages
6. Test all edge case scenarios

**Success Criteria:**
- Spec modifications detected and warned about
- `--from-task N` starts execution from task N
- `--restart` ignores completed tasks
- All edge cases handled gracefully

### Phase 5: Integration & Polish

**Tasks:**
1. Integrate `/compound` prompt on completion
2. Add completion summary with task breakdown
3. Implement progress indicators
4. Add helpful error messages with suggestions
5. Update `/status` command if needed for /continue state
6. Write documentation and examples

**Success Criteria:**
- User prompted for `/compound` after completion
- Completion summary shows task breakdown
- All error messages are actionable
- Documentation is clear

## Dependencies & Risks

### Dependencies

- **Existing `/build` command** - Must store agentId in task metadata
- **Existing `/continue <agent-id>`** - Patterns for agent resume
- **Task tool** - Must support metadata field
- **TaskOutput tool** - Must support non-blocking checks with timeout

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| TaskList doesn't preserve agentId | Can't resume agents | Store agentId in metadata during /build |
| Agent becomes inaccessible between sessions | Lost context | Check accessibility, fallback to fresh deploy |
| Spec modification causes task mismatch | Wrong work done | Detect and warn, let user decide |
| Task metadata field not supported | Can't store agentId | Verify TaskUpdate supports metadata |
| Dependencies circular | Deadlock | Topological sort by blockedBy |

## Alternative Approaches Considered

### Approach A: Separate State File

**Description:** Store task-to-agent mappings in `.claude/build-state.yml` instead of task metadata.

**Pros:**
- Centralized state management
- Easy to inspect and debug

**Cons:**
- Additional file to manage
- State can get out of sync with TaskList
- More complex cleanup needed

**Why Rejected:** Task metadata is simpler and keeps state with the task itself. The hybrid approach in the brainstorm uses metadata.

### Approach B: Re-parse Spec for Each Task

**Description:** Re-read spec file for each task to get latest requirements.

**Pros:**
- Always uses latest spec definitions
- No stale task descriptions

**Cons:**
- Spec could change mid-build, causing inconsistency
- More expensive (parsing spec for each task)
- Loses connection between original task definition and current state

**Why Rejected:** TaskList should be authoritative. Re-parsing spec could cause task definitions to change mid-build, leading to confusion.

### Approach C: Always Fresh Deploy

**Description:** Don't try to resume agents - always deploy fresh.

**Pros:**
- Simpler implementation
- No stale context issues

**Cons:**
- Loses valuable agent context
- Wastes time re-learning what agent already knew
- Defeats the purpose of "smart resume"

**Why Rejected:** The brainstorm specifically chose "Hybrid Approach" to preserve context when possible. This is a key feature.

## Validation Commands

After implementation, validate with:

```bash
# Test basic resume
/plan_w_team "Create a simple feature with 3 tasks"
/build specs/simple-feature.md
# Cancel during task 2
/continue specs/simple-feature.md

# Test with dry-run
/continue specs/simple-feature.md --dry-run

# Test with spec modification
# (Modify specs/simple-feature.md during build)
/continue specs/simple-feature.md

# Test from specific task
/continue specs/simple-feature.md --from-task 2

# Test restart
/continue specs/simple-feature.md --restart
```

## Examples

### Example 1: Normal Resume

```bash
$ /build specs/user-auth.md
[Creates tasks 1-10, completes 1-3, fails on 4, user cancels]

$ /continue specs/user-auth.md

🔍 Detecting Build State...

Previous Build Status:
✅ Completed: 3 tasks (1, 2, 3)
⚠️ In-Progress: 1 task (4 - failed)
⏳ Pending: 6 tasks (5-10)

⚠️ Task 4 "Implement JWT endpoints" is in-progress

Last output:
Error: Failed to import jwt library...

What should we do?
> [Resume] Continue from where agent left off
> [Restart] Start this task over from beginning
> [Skip] Mark as completed and move on

[User selects: Restart]

🔄 Restarting task 4...
[Task 4 completes]

✅ Continuing with remaining tasks...
[Tasks 5-10 complete]

✅ All Tasks Complete!
Tasks: 10/10 completed
Duration: 12 minutes

📚 Document Learnings
Run /compound to capture learnings from this build:
  /compound specs/user-auth.md
```

### Example 2: Dry Run

```bash
$ /continue specs/user-auth.md --dry-run

🔍 Dry Run Mode - No changes will be made

Would resume:
✅ Skip 3 completed tasks
🔄 Resume task 4 (agent: abc123 - accessible)
🆕 Fresh deploy tasks 5-10

Total: 7 tasks would be executed
Estimated time: ~15 minutes

Run without --dry-run to execute.
```

### Example 3: From Specific Task

```bash
$ /continue specs/user-auth.md --from-task 5

🔍 Starting from task 5

Skipping tasks 1-4 (assumed completed)

📋 Pending Tasks:
- Task 5: Build user model
- Task 6: Create user controller
- Task 7: Add user routes
- Task 8: Write user tests
- Task 9: Integration testing
- Task 10: Documentation

[Executes tasks 5-10...]
```

### Example 4: Spec Modified Warning

```bash
$ /continue specs/user-auth.md

⚠️ Spec modified since last build!
  Modified: 2026-02-04 15:30:00
  Build started: 2026-02-04 14:00:00

Changes may not be reflected in ongoing tasks.

What would you like to do?
> [Continue] Proceed with current task state
> [Restart] Run /build to pick up new spec changes
```

## Related Documentation

### Internal References

- Current `/continue <agent-id>` command: `.claude/commands/continue.md:1-112`
- `/build` command orchestration: `.claude/commands/build.md:46-248`
- Task Management Tools: `.claude/commands/plan-w-team.md:285-370`
- Brainstorm document: `docs/brainstorms/2026-02-04-continue-command-brainstorm.md`

### External References

- Task tool documentation: Claude Code Task tool reference
- Multi-agent orchestration patterns: compound engineering best practices

### Related Work

- Compound command: `.claude/commands/compound.md` - For documenting learnings after build
- Status command: `.claude/commands/status.md` - For viewing current task/agent state

## Success Metrics

| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| Resume time (vs full rebuild) | N/A | <10% of full build | Time comparison |
| Agent context preservation | N/A | >90% when agents accessible | Success rate of resume |
| Edge case handling | N/A | 100% of documented cases | Test coverage |
| User satisfaction | N/A | Can resume interrupted builds | Qualitative feedback |
