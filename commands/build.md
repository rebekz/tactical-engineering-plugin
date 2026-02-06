---
name: build
description: Execute a plan document from specs/ directory with multi-agent coordination. Use after planning to implement the feature.
argument-hint: [path-to-plan]
model: opus
allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, NotebookEdit, WebFetch, WebSearch, AskUserQuestion, Skill, TodoWrite
---

# Build

Execute the implementation plan at `PATH_TO_PLAN` using multi-agent coordination. This command parses the plan, creates tasks, deploys agents, and manages the execution workflow.

## Variables

- `PATH_TO_PLAN`: $1 - Path to the plan file (e.g., `specs/conversational-ui-revamp.md`)
- `TEAM_MEMBERS`: `agents/*.md` - Available team members
- `GENERAL_PURPOSE_AGENT`: `general-purpose` - Default agent type

## Instructions

### Prerequisites

- If no `PATH_TO_PLAN` is provided, STOP and ask the user to provide it
- The plan must exist and follow the plan format created by `plan_w_team`
- Read the plan document completely before starting execution

### Execution Strategy

You are the **Orchestrator** - your job is to coordinate multiple agents to execute the plan, NOT to write code directly.

#### Core Principles

1. **Parse the Plan** - Extract all tasks, dependencies, and team assignments
2. **Create Task List** - Use `TaskCreate` to create all tasks in the shared task list
3. **Set Dependencies** - Use `TaskUpdate` with `addBlockedBy` to establish task dependencies
4. **Deploy Agents** - Use `Task` tool to deploy agents for each assigned task
5. **Monitor Progress** - Use `TaskList` and `TaskOutput` to track progress
6. **Handle Failures** - If an agent fails, assess and either retry or adjust approach

#### DO NOT Write Code Directly

Your role is ORCHESTRATION, not IMPLEMENTATION. Use agents to do the actual work:
- `TaskCreate` - Create tasks in the shared list
- `TaskUpdate` - Update task status and dependencies
- `Task` - Deploy agents to execute work

## Workflow

### Phase 0: Resume Detection (NEW)

Before starting, check for existing state from a previous build:

```typescript
// Load state file helper functions
// Note: These functions are available in scripts/state-file.js
// For now, implement inline or load as needed

const existingState = readStateFile(PATH_TO_PLAN)

if (existingState) {
  const inProgressTasks = existingState.tasks.filter(t => t.status === 'in-progress')
  const completedTasks = existingState.tasks.filter(t => t.status === 'completed')

  if (inProgressTasks.length > 0) {
    // Previous build was interrupted
    console.log(`Previous build found:`)
    console.log(`- Status: In-progress (${completedTasks.length}/${existingState.build.totalTasks} tasks completed)`)
    console.log(`- Started: ${existingState.build.startedAt}`)

    const action = await AskUserQuestion({
      question: "What would you like to do?",
      options: [
        { label: "Resume", description: "Continue from where we left off" },
        { label: "Fresh", description: "Start over from beginning" }
      ]
    })

    if (action === "Fresh") {
      deleteStateFile(PATH_TO_PLAN)
      console.log("Starting fresh build...")
      // Proceed with fresh build
    } else {
      // Resume logic - jump to Phase 4 with existing tasks
      console.log("Resuming previous build...")
      return resumeBuild(existingState)
    }
  }
  // If all completed, auto-start fresh without asking
  console.log("Previous build completed. Starting fresh build...")
  deleteStateFile(PATH_TO_PLAN)
}
```

### Phase 1: Parse & Prepare

1. **Read the Plan** - Read `PATH_TO_PLAN` completely
2. **Extract Tasks** - Parse all tasks from the "Step by Step Tasks" section
3. **Extract Team Members** - Parse the "Team Members" section
4. **Validate Plan** - Ensure plan has required sections

### Phase 2: Create Task List

Use `TaskCreate` to create all tasks in the shared task list:

```typescript
// Create initial task
TaskCreate({
  subject: "<Task Name>",
  description: "<Full task description from plan>",
  activeForm: "<Active form - what shows in spinner>"
})
// Returns: taskId (e.g., "1")

// Create all tasks before starting execution
```

Create ALL tasks first before deploying any agents. This gives full visibility into the work.

**IMPORTANT: Create State File After Task Creation**

After creating all tasks, immediately persist them to the state file:

```typescript
// After creating all tasks:
const tasks = []  // Array of task objects with their IDs

for (const taskDef of parsedTasks) {
  const result = await TaskCreate({
    subject: taskDef.subject,
    description: taskDef.description,
    activeForm: taskDef.activeForm
  })
  tasks.push({ ...taskDef, id: result.taskId })
}

// Create initial state file
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
    status: t.status || 'pending',
    activeForm: t.activeForm,
    blockedBy: t.blockedBy || [],
    agentType: t.agentType || 'general-purpose'
  })),
  artifacts: [],
  validation: { commandsRun: [], acceptanceCriteria: [] }
}

writeStateFile(PATH_TO_PLAN, state)
console.log(`✓ State saved to .claude/specs/${sanitizeSpecName(PATH_TO_PLAN)}/state.json`)
```

### Phase 3: Set Dependencies

Use `TaskUpdate` with `addBlockedBy` to establish dependencies:

```typescript
// Example: Task 2 depends on Task 1
TaskUpdate({
  taskId: "2",
  addBlockedBy: ["1"]
})

// Example: Task 3 depends on both Task 1 and Task 2
TaskUpdate({
  taskId: "3",
  addBlockedBy: ["1", "2"]
})
```

### Phase 4: Deploy Agents

Use the `Task` tool to deploy agents for each task:

```typescript
// Deploy an agent to execute a task
Task({
  description: "<Task Name>",
  prompt: `<Detailed instructions for the agent>

Execute the following task:
- Task ID: <taskId>
- Task Name: <task name>
- Requirements: <from plan>
- Files: <from Relevant Files section>
- Acceptance Criteria: <from plan>

Work through the implementation step by step.
Report progress as you complete each subtask.`,

  subagent_type: "<agent type from plan>",
  model: "opus",
  run_in_background: <true for parallel, false for sequential>
})
```

#### Parallel vs Sequential

- **Parallel** (`run_in_background: true`): Task has no dependencies or can run independently
- **Sequential** (`run_in_background: false`): Task depends on other tasks completing first

### Phase 5: Monitor & Coordinate

While agents are working:

1. **Check Progress** - Use `TaskList` to see task statuses
2. **Monitor Agents** - Use `TaskOutput` to check on running agents
3. **Handle Completions** - When agent finishes, mark task as completed
4. **Unblock Tasks** - Completed tasks unblock dependent tasks
5. **Deploy Next Agents** - Start agents for newly unblocked tasks

```typescript
// Check on a background agent
TaskOutput({
  task_id: "<agentId>",
  block: false,  // Non-blocking check
  timeout: 5000
})

// Wait for agent completion
TaskOutput({
  task_id: "<agentId>",
  block: true,  // Blocks until done
  timeout: 300000  // 5 minutes
})
```

### Phase 6: Resume Pattern

For follow-up work on the same task, resume the existing agent:

```typescript
// First deployment - returns agentId
Task({
  description: "Build user service",
  prompt: "Create the user service...",
  subagent_type: "general-purpose"
})
// Returns: agentId: "abc123"

// Later - resume SAME agent with preserved context
Task({
  description: "Continue user service",
  prompt: "Now add validation to what you created...",
  subagent_type: "general-purpose",
  resume: "abc123"  // Critical: preserves context
})
```

### Phase 5.5: Per-Task Validation Hooks (NEW)

**Critical:** Before marking any task as "completed", run validation hooks defined in the spec.

```typescript
// After agent finishes, run validation hooks before marking complete
// In Phase 5: Monitor & Coordinate - after TaskOutput returns

const result = await TaskOutput({ task_id: agentId, block: true })

// Load validation hooks from spec
const hooks = extractTaskHooks(specContent, task.subject)

if (hooks && hooks.stop && hooks.stop.length > 0) {
  console.log(`Running ${hooks.stop.length} validation hook(s) for task ${taskId}...`)

  const validationResults = await runHooks(hooks.stop, {
    agentOutput: result.output || '',
    taskId: taskId,
    specPath: PATH_TO_PLAN,
    workingDir: process.cwd()
  })

  // Display validation results
  console.log(`Validation: ${validationResults.passed}/${validationResults.total} passed`)

  if (validationResults.failed > 0) {
    console.error(`❌ Validation failed:`)
    validationResults.errors.forEach(err => console.error(`  - ${err}`))

    // Ask user what to do
    const action = await AskUserQuestion({
      question: `Task "${task.subject}" validation failed. What should we do?`,
      options: [
        {
          label: "Retry task",
          description: "Run agent again with same prompt"
        },
        {
          label: "Mark complete anyway",
          description: "Ignore validation failures and mark as completed"
        },
        {
          label: "Skip task",
          description: "Mark as skipped and continue to next task"
        },
        {
          label: "Abort build",
          description: "Stop the entire build process"
        }
      ]
    })

    // Handle user choice
    switch (action) {
      case "Retry task":
        // Resume agent with same prompt
        console.log(`Retrying task ${taskId}...`)
        const retryResult = await Task({
          description: task.subject,
          prompt: buildPrompt(task),
          subagent_type: task.agentType,
          resume: result.agentId
        })
        // Re-run validation...
        break

      case "Mark complete anyway":
        // Proceed to mark as completed
        console.log(`Marking task ${taskId} as complete despite validation failures...`)
        break

      case "Skip task":
        await TaskUpdate({ taskId: taskId, status: "deleted" })
        updateTaskInState(PATH_TO_PLAN, taskId, { status: "skipped" })
        // Continue to next task without marking complete
        continue

      case "Abort build":
        console.log("Build aborted by user.")
        return
    }
  } else {
    console.log(`✓ All validation hooks passed`)
  }
}

// Only mark complete if validation passed (or user chose to mark complete anyway)
await TaskUpdate({ taskId: taskId, status: "completed" })
updateTaskInState(PATH_TO_PLAN, taskId, {
  status: "completed",
  lastOutput: result.output?.slice(0, 500) || "",
  validationResults: validationResults
})
```

**Hook Format in Spec:**

Tasks can define validation hooks using YAML:

```markdown
### Task 1: Create user model
- [ ] Task 1: Create user model

**Validation:**
```yaml
stop:
  - type: artifact
    path: app/models/user.rb
    exists: true
  - type: command
    command: rails runner "puts User.column_names"
    expect: exit_code_0
  - type: agent_output
    validate: success
  - type: acceptance_criteria
    criteria:
      - "User model created"
      - "Email field present"
    require: all
```
```

**Validation Types:**

| Type | Description | Example |
|------|-------------|---------|
| `agent_output` | Validates agent output for success/errors | `validate: success` |
| `command` | Runs shell command and checks result | `command: test -f file.rb` |
| `artifact` | Checks file existence/content | `path: app/model.rb`, `exists: true` |
| `acceptance_criteria` | Verifies spec criteria are checked | `criteria: ["Model created"]` |

**On Failure Behavior:**

Hooks can specify `on_failure`:
- `fail` (default): Stop running more hooks, prompt user
- `continue`: Run remaining hooks, report all failures at end
- `retry`: Automatically retry the task (up to N times)

### Phase 7: Validation

When all implementation tasks complete:

1. **Run Validation Commands** - Execute commands from "Validation Commands" section
2. **Verify Acceptance Criteria** - Check all criteria are met
3. **Update Task Status** - Mark validation task as completed
4. **Update State File** - Final state write with validation results

```typescript
// Update validation section
const state = readStateFile(PATH_TO_PLAN)
if (state) {
  state.validation.commandsRun = validationCommandsRun
  state.validation.acceptanceCriteria = acceptanceCriteriaStatus
  state.build.lastUpdated = new Date().toISOString()
  writeStateFile(PATH_TO_PLAN, state)
}
```

### Phase 8: State Updates During Execution

**Critical:** Keep the state file updated as tasks progress:

```typescript
// Mark task as in_progress
await TaskUpdate({ taskId: taskId, status: "in_progress" })
updateTaskInState(PATH_TO_PLAN, taskId, { status: "in_progress" })

// Deploy agent, store agentId
const result = await Task({
  description: task.subject,
  prompt: buildPrompt(task),
  subagent_type: task.agentType,
  run_in_background: false
})

updateTaskInState(PATH_TO_PLAN, taskId, {
  agentId: result.agentId,
  deployedAt: new Date().toISOString()
})

// On task completion
await TaskUpdate({ taskId: taskId, status: "completed" })
updateTaskInState(PATH_TO_PLAN, taskId, {
  status: "completed",
  lastOutput: result.output?.slice(0, 500) || ""
})

// Track artifacts (optional but recommended)
state.artifacts.push({
  taskId: taskId,
  action: "created", // or "modified"
  path: "path/to/file",
  timestamp: new Date().toISOString()
})
writeStateFile(PATH_TO_PLAN, state)
```

**State Update Milestones:**
- After Phase 2 (all tasks created)
- After each task completion
- After each agent deployment (store agentId)
- On build completion
- On any interruption/error

### Helper Functions Reference

The following functions are available:

**State File Helpers** (see `scripts/state-file.js`):

```javascript
// Get state file path from spec path
getStateFilePath(specPath) // Returns: ".claude/specs/user-auth/state.json"

// Calculate spec checksum
calculateChecksum(specPath) // Returns: "sha256:abc123..."

// Read state file
readStateFile(specPath) // Returns: state object or null

// Write state file
writeStateFile(specPath, state) // Creates directory if needed

// Update specific task
updateTaskInState(specPath, taskId, updates) // Merges updates

// Delete state file
deleteStateFile(specPath) // Removes state directory

// Sanitize spec name
sanitizeSpecName(specPath) // "specs/user-auth.md" -> "user-auth"

// Rebuild from TaskList
rebuildStateFromTaskList(tasks, specPath) // Auto-repair
```

**Validation Hooks Helpers** (see `scripts/hooks.js`):

```javascript
// Extract hooks YAML from a task section in spec
extractTaskHooks(specContent, taskSubject) // Returns: { stop: [...] } or null

// Parse YAML hooks content into structured object
parseHooksYAML(yamlContent) // Returns: { stop: [hooks] }

// Run all validation hooks for a task
runHooks(hooks, context) // Returns: { passed, failed, errors, details }

// Run a single validation hook
runSingleHook(hook, context) // Returns: { passed, error }

// Validate agent output
validateAgentOutput(hook, output) // Checks for success/errors/patterns

// Validate command execution
validateCommand(hook, workingDir) // Runs command, checks exit/output

// Validate artifact existence and content
validateArtifact(hook, workingDir) // Checks file exists/content

// Validate acceptance criteria from spec
validateAcceptanceCriteria(hook, specPath) // Checks checkboxes
```

## Task Execution Example

### Sequential Execution

```typescript
// Task 1: Setup database (no dependencies)
TaskUpdate({ taskId: "1", status: "in_progress" })
Task({
  description: "Setup database",
  prompt: "Create database schema...",
  subagent_type: "general-purpose",
  run_in_background: false
})
// Wait for completion...
TaskUpdate({ taskId: "1", status: "completed" })

// Task 2: Build API (depends on Task 1)
TaskUpdate({ taskId: "2", status: "in_progress" })
Task({
  description: "Build API endpoints",
  prompt: "Implement REST API...",
  subagent_type: "general-purpose",
  run_in_background: false
})
// Wait for completion...
TaskUpdate({ taskId: "2", status: "completed" })
```

### Parallel Execution

```typescript
// Start Task 1 (Frontend)
TaskUpdate({ taskId: "1", status: "in_progress" })
Task({
  description: "Build frontend",
  prompt: "Create UI components...",
  subagent_type: "frontend-agent",
  run_in_background: true  // Non-blocking
})
// Returns: agentId1

// Start Task 2 (Backend) - can run in parallel
TaskUpdate({ taskId: "2", status: "in_progress" })
Task({
  description: "Build backend API",
  prompt: "Create API endpoints...",
  subagent_type: "backend-agent",
  run_in_background: true  // Non-blocking
})
// Returns: agentId2

// Both agents now working in parallel...

// Wait for Task 1
TaskOutput({ task_id: agentId1, block: true })
TaskUpdate({ taskId: "1", status: "completed" })

// Wait for Task 2
TaskOutput({ task_id: agentId2, block: true })
TaskUpdate({ taskId: "2", status: "completed" })

// Task 3 (Integration) depends on both 1 and 2
TaskUpdate({ taskId: "3", status: "in_progress" })
Task({
  description: "Integration testing",
  prompt: "Test frontend + backend...",
  subagent_type: "test-agent",
  run_in_background: false
})
```

## Error Handling

If an agent fails:

1. **Assess the Error** - Read the error message from `TaskOutput`
2. **Determine Cause** - Is it a code error, missing dependency, or unclear requirements?
3. **Choose Action**:
   - **Retry** - For transient errors, resume the agent with corrected instructions
   - **Adjust** - Update the prompt with clarification
   - **Skip** - If task is optional, mark as completed and note the issue
4. **Document** - Add note to the plan about the issue and resolution

## Progress Updates

Provide regular progress updates to the user:

```
🔄 Build Progress

Phase 1: Foundation
✅ Task 1: Setup database
✅ Task 2: Create migrations
🔄 Task 3: Configure API Gateway (in progress)

Phase 2: Core Implementation
⏳ Task 4: Build frontend (waiting for Task 3)
⏳ Task 5: Build backend (waiting for Task 3)

Agents Running:
- agent-abc123: Working on API Gateway configuration
```

## Completion Report

When all tasks are complete, provide:

```
✅ Build Complete!

Plan: specs/<plan-name>.md
Duration: <time taken>
Tasks Completed: <N>/<N>

Summary:
- <Component 1>: ✅ Complete
- <Component 2>: ✅ Complete
- <Component 3>: ✅ Complete

Validation:
✅ All validation commands passed
✅ All acceptance criteria met

Files Modified:
- <list of files created/modified>

📚 Document Learnings
Run /compound to capture learnings from this build:
  /compound specs/<plan-name>.md

This creates ADRs, solutions, and updates patterns for future builds.
Each build makes future builds easier by capturing what was learned.

💾 State Saved
Build state persisted to: .claude/specs/<spec-name>/state.json
Run /continue-spec to resume across sessions:
  /continue-spec specs/<plan-name>.md
```

## Report Format

After completing the build, provide a concise report following the Completion Report format above.

## Examples

```bash
# Basic usage
/build specs/conversational-ui-revamp.md

# Resume from previous build (auto-detected)
/build specs/user-auth.md
# > Previous build found: Resume or Fresh?

# Force fresh start (ignore existing state)
/build specs/user-auth.md --fresh

# With specific phase
/build specs/conversational-ui-revamp.md --phase 2

# Continue from specific task
/build specs/conversational-ui-revamp.md --from-task setup-database
```

## Tips

1. **Create ALL tasks first** - Before deploying any agents, create the full task list
2. **Use descriptive prompts** - Give agents clear, detailed instructions
3. **Monitor actively** - Check on agents regularly, don't just wait
4. **Resume when appropriate** - Use resume pattern for follow-up work on same task
5. **Handle failures gracefully** - Assess and recover, don't just fail
6. **Communicate progress** - Keep user informed of what's happening
