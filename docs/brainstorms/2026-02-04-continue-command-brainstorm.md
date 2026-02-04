---
title: "/continue Command - Resume Work from Spec"
date: 2026-02-04
status: brainstorm
type: workflow
tags: [workflow, continue, resume, multi-agent, task-management]
---

# /continue Command - Resume Work from Spec

## What We're Building

A `/continue` command that resumes work from a spec file, intelligently detecting which tasks are complete and which remain. Unlike the existing `/continue <agent-id>` command (which resumes a specific agent), this command resumes the **entire build workflow** from a spec.

**Key distinction:**
- **Existing `/continue abc123`** → Resumes one specific agent
- **New `/continue specs/feature.md`** → Resumes entire build workflow from spec

## Why This Approach

### Problem Solved

When `/build` is interrupted (user cancels, error occurs, session times out):
- Some tasks may be completed
- Some tasks may be in-progress
- Some tasks may be pending
- Agents may or may not still be accessible

Current options are limited:
- Re-run entire `/build` (wastes completed work)
- Manually resume each agent (tedious, error-prone)
- No way to "pick up where we left off"

### Design Philosophy

**Smart Resume** - The command should:
1. Detect current state from TaskList
2. Continue from where work stopped
3. Handle failures gracefully
4. Preserve agent context when possible
5. Provide clear progress feedback

---

## Key Decisions

### Decision 1: Spec Path Required

**Choice:** User must specify which spec to continue

```bash
/continue specs/feature-name.md
```

**Rationale:**
- Unambiguous - no guessing which spec to use
- User has full control
- Avoids accidental wrong spec

**Trade-off:** Requires user to know spec path (but they just ran /build on it, so they should know)

---

### Decision 2: Smart State Detection

**Choice:** Read TaskList state to determine what's done

**Detection Logic:**

```typescript
// 1. Read all tasks from TaskList
const allTasks = await TaskList({})

// 2. Categorize by status
const completed = allTasks.filter(t => t.status === 'completed')
const inProgress = allTasks.filter(t => t.status === 'in_progress')
const pending = allTasks.filter(t => t.status === 'pending')

// 3. Make smart decisions
if (inProgress.length > 0) {
  // Resume in-progress tasks first
  // Ask if user wants to retry or reset
}

if (pending.length > 0) {
  // Continue with pending tasks
  // Respect dependency chains (blockedBy)
}

if (allTasks.length === 0) {
  // Edge case: No task state
  // Fall back to starting fresh build
}
```

**Why TaskList instead of spec parsing:**
- TaskList is the **source of truth** for execution state
- Spec checkboxes may be stale (not updated if build crashed)
- TaskList has dependency info (blockedBy)
- TaskList has owner assignments

---

### Decision 3: Hybrid Agent Resume Approach

**Choice:** Resume agents that are accessible, fresh deploy for ones that aren't

**Resume Logic:**

```typescript
for (const task of pendingTasks) {
  const taskDetails = await TaskGet({ taskId: task.id })

  // Check if task has an associated agent from previous run
  const agentId = taskDetails.metadata?.agentId

  if (agentId && isAgentAccessible(agentId)) {
    // Resume existing agent (preserves context!)
    await Task({
      description: taskDetails.subject,
      prompt: buildPromptFromSpec(taskDetails),
      subagent_type: taskDetails.agentType,
      resume: agentId  // ← Critical: preserves context
    })
  } else {
    // Fresh deployment (no agent or agent lost)
    await Task({
      description: taskDetails.subject,
      prompt: buildPromptFromSpec(taskDetails),
      subagent_type: taskDetails.agentType,
      run_in_background: false
    })
  }
}

function isAgentAccessible(agentId) {
  try {
    const output = await TaskOutput({
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

**Benefits:**
- Preserves valuable agent context when possible
- Gracefully handles lost agents
- No manual intervention needed

---

### Decision 4: Failure Investigation

**Choice:** When tasks are in-progress or failed, investigate before retrying

**Investigation Flow:**

```typescript
const inProgressTasks = allTasks.filter(t => t.status === 'in_progress')

if (inProgressTasks.length > 0) {
  console.log(`⚠️ Found ${inProgressTasks.length} in-progress tasks`)

  for (const task of inProgressTasks) {
    const output = await TaskOutput({
      task_id: task.metadata?.agentId,
      block: false,
      timeout: 5000
    })

    // Show user what happened
    console.log(`\nTask: ${task.subject}`)
    console.log(`Status: ${task.status}`)
    console.log(`Last output: ${output.slice(0, 500)}...`)

    // Ask what to do
    const action = await AskUserQuestion({
      question: `Task "${task.subject}" is in-progress. What should we do?`,
      options: [
        { label: "Resume", description: "Continue from where agent left off" },
        { label: "Restart", description: "Start this task over from beginning" },
        { label: "Skip", description: "Mark as completed and move on" }
      ]
    })

    // Take action based on user choice...
  }
}
```

**User stays in control** of how to handle failures.

---

### Decision 5: Edge Case Handling

| Edge Case | Detection | Handling |
|-----------|-----------|----------|
| **Spec never built** | TaskList returns empty tasks | Prompt: "No previous build found. Run full `/build` first?" |
| **No task state** | TaskList empty or error | Suggest running `/build` or ask if spec was modified |
| **Spec changed** | Compare spec mtime with task creation | Warn: "Spec modified since last build. Changes may not be reflected." |
| **Agents lost** | TaskOutput fails for agentId | Fresh deploy with clear message: "Agent no longer accessible, starting fresh" |

---

### Decision 6: Prompt for /compound on Completion

**Choice:** When all tasks complete, prompt to run `/compound`

**After completion report:**

```typescript
AskUserQuestion({
  question: "All tasks complete! Would you like to document learnings?",
  options: [
    { label: "Run /compound", description: "Capture learnings (ADRs, solutions, patterns)" },
    { label: "Skip for now", description: "I'll run /compound manually later" }
  ]
})
```

**Why prompt instead of auto-run:**
- User may want to review work first
- Some builds aren't worth documenting
- Gives user control

---

## Open Questions

### Q1: How to handle spec modifications during build?

**Scenario:** User modifies spec after /build started but before /continue

**Options:**
1. **Detect and warn** - Compare modification times, show warning
2. **Re-parse spec** - Re-read spec for each task (could change task definitions mid-build!)
3. **Ignore** - Use original task definitions, spec changes ignored

**Recommendation:** Option 1 (detect and warn). Show which tasks might be affected, ask if user wants to restart or continue.

---

### Q2: Should /continue update spec checkboxes?

**Scenario:** Tasks complete, but spec checkboxes aren't marked

**Current behavior:** `/build` marks checkboxes as it completes tasks

**Options:**
1. **Mark during /continue** - Update checkboxes as tasks complete
2. **Mark only on full build** - Only /build updates spec
3. **Manual only** - User must manually check off items

**Recommendation:** Option 1 (mark during /continue). This keeps spec in sync with reality, whether build was completed in one session or resumed across sessions.

---

### Q3: How to track agent-to-task mappings?

**Problem:** TaskList doesn't store which agent was deployed for a task

**Options:**
1. **Store in task metadata** - `TaskUpdate` with `metadata: { agentId: "abc123" }`
2. **Store in separate file** - `.claude/build-state.yml` maps tasks to agents
3. **Re-derive from spec** - Match task subject to spec task definition

**Recommendation:** Option 1 (metadata). TaskUpdate supports metadata field, and it keeps state with the task itself.

**Example:**
```typescript
TaskUpdate({
  taskId: "1",
  status: "in_progress",
  owner: "builder-api",
  metadata: {
    agentId: "abc123",
    deployedAt: "2026-02-04T10:30:00Z"
  }
})
```

---

## Proposed Command Interface

```bash
# Basic usage
/continue specs/feature-name.md

# With specific task override
/continue specs/feature-name.md --from-task 5

# Dry run (show what would be done)
/continue specs/feature-name.md --dry-run

# Force restart (ignore completed tasks, start fresh)
/continue specs/feature-name.md --restart
```

---

## Example Workflow

```
$ /build specs/user-auth.md

[Build starts, creates tasks 1-10]
[Tasks 1-3 complete]
[Task 4 fails due to error]
[User cancels to investigate]

$ /continue specs/user-auth.md

🔍 Detecting Build State...

Previous Build Status:
- Completed: 3 tasks (1, 2, 3)
- In-Progress: 1 task (4 - failed)
- Pending: 6 tasks (5-10)

⚠️ Task 4 "Implement JWT endpoints" is in-progress

Last output:
Error: Failed to import jwt library...

What should we do?
> 1. Resume - Continue from where agent left off
> 2. Restart - Start this task over from beginning
> 3. Skip - Mark as completed and move on

[User selects: Restart]

🔄 Restarting task 4...
[Task 4 completes successfully]

✅ Continuing with remaining tasks...
[Tasks 5-10 complete]

✅ All Tasks Complete!

Tasks: 10/10 completed
Duration: 15 minutes

📚 Document Learnings
Run /compound to capture learnings from this build:
  /compound specs/user-auth.md
```

---

## Next Steps

1. **Run `/workflows:plan`** - Create implementation plan for `/continue` command
2. **Define state tracking** - How to map tasks to agents in metadata
3. **Implement detection logic** - TaskList parsing, agent accessibility check
4. **Add edge case handling** - All 4 edge cases identified above
5. **Test with interrupted builds** - Simulate failure scenarios
6. **Integrate with /compound** - Prompt flow after completion

---

## Related Brainstorms

None yet - this is the first brainstorm about `/continue`.

---

## Related Commands

- `/plan` - Create spec (input to /build)
- `/build` - Execute spec (creates TaskList state)
- `/continue <agent-id>` - Resume specific agent
- `/compound` - Document learnings after build completes
- `/status` - View build and agent status

---

## References

- Current `/continue` command: `.claude/commands/continue.md`
- `/build` command: `.claude/commands/build.md`
- `/plan-w-team` command: `.claude/commands/plan-w-team.md`
- Task orchestration: plan-w-team.md#team-orchestration section
