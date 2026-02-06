---
name: status
description: Show the current status of all tasks and running agents. Use to monitor build progress.
argument-hint:
model: opus
allowed-tools: Task, TaskOutput, TaskList, TaskGet, Bash, Glob, Grep, Read
---

# Status

Show the current status of all tasks in the task list and any running agents.

## Variables

None

## Instructions

1. **Get Task List** - Use `TaskList` to retrieve all tasks
2. **Get Task Details** - Use `TaskGet` for tasks with status "in_progress"
3. **Check Running Agents** - If there are background agents, check their status
4. **Check Team Mode** - Read state file to detect if this is a team-mode build. If so, read team config for teammate info.

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

## Team Mode Output

If the build is running in Agent Teams mode (detected from state file `build.mode === "team"`):

Read the state file from `.claude/specs/<spec-name>/state.json` to detect team mode.
Read the team config from `~/.claude/teams/<teamName>/config.json` for teammate details.

```
Build Mode: Agent Teams
Team: <teamName>

Teammates:
| Name | Agent Type | Current Task | Status |
|------|-----------|-------------|--------|
| backend-api | backend-agent | [3] Build auth API | Working |
| frontend-ui | frontend-agent | [5] Create login | Working |
| test-runner | test-agent | (idle) | Waiting |

Task Progress:
Completed: X/Y tasks
Remaining: Z tasks

Recent Messages:
- backend-api: "Completed Task 2, claiming Task 4"
- frontend-ui: "Need API contract from backend-api"
```

## Workflow

1. Call `TaskList({})` to get all tasks
2. Format output by status (pending, in_progress, completed)
3. Show dependencies for blocked tasks
4. If there are background agents, show their status
5. Read state file to detect team mode. If team mode, read team config and show teammate table.

## Report

Provide a concise status report showing:
- Total task count
- Completed count
- In progress count
- Pending count
- Blocked count
- Build mode (subagent/team)
- Teammate names and assignments (if team mode)

## Examples

```bash
# Show all tasks
/status

# Show only pending tasks
/status --pending

# Show only in-progress tasks
/status --active
```
