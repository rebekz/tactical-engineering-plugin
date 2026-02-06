---
name: status
description: Show the current status of all tasks and running agents. Use to monitor build progress.
argument-hint:
model: opus
allowed-tools: Task, TaskOutput, TaskList, TaskGet
---

# Status

Show the current status of all tasks in the task list and any running agents.

## Variables

None

## Instructions

1. **Get Task List** - Use `TaskList` to retrieve all tasks
2. **Get Task Details** - Use `TaskGet` for tasks with status "in_progress"
3. **Check Running Agents** - If there are background agents, check their status

## Output Format

```
📋 Task Status

Pending Tasks (ready to start):
- [<ID>] <Task Name>

In Progress:
- [<ID>] <Task Name> (assigned to: <owner>)
  Status: <details>

Completed:
- [<ID>] <Task Name> ✅

Blocked (waiting for dependencies):
- [<ID>] <Task Name> (blocked by: <task IDs>)
```

If there are running background agents:

```
🤖 Running Agents

- Agent <ID>: <Task Name>
  Status: <running/completed/error>
  Output file: <path>
```

## Workflow

1. Call `TaskList({})` to get all tasks
2. Format output by status (pending, in_progress, completed)
3. Show dependencies for blocked tasks
4. If there are background agents, show their status

## Report

Provide a concise status report showing:
- Total task count
- Completed count
- In progress count
- Pending count
- Blocked count

## Examples

```bash
# Show all tasks
/status

# Show only pending tasks
/status --pending

# Show only in-progress tasks
/status --active
```
