---
name: get_it_done
description: Full autonomous engineering workflow. Chains ralph-check, brainstorm, plan, build, and validate into one command.
argument-hint: [feature description | --accept path | --bmad path] [--brainstorm] [--ralph [--max-iterations N] [--completion-promise TEXT]]
model: opus
allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, NotebookEdit, WebFetch, WebSearch, AskUserQuestion, Skill, TodoWrite, TeamCreate, TeamDelete, SendMessage
---

# Get It Done

Full autonomous engineering workflow. Run these steps in order. Do not stop between steps after planning completes — complete every step through to the end.

## Variables

- `ARGUMENTS`: $1..N - All arguments passed to the command
- `BRAINSTORM_FLAG`: Detected from `--brainstorm` in arguments
- `RALPH_FLAGS`: Detected from `--ralph` and sub-flags (`--max-iterations`, `--completion-promise`)
- `PLAN_PATH`: Set after /plan-w-team completes — path to generated spec file

## Instructions

### Step 1: Ralph Loop Check (optional)

Check if the `ralph-loop:ralph-loop` skill is available. If available, invoke it to wrap the entire workflow in an autonomous iteration loop. If not available, skip silently and proceed to Step 2.

```typescript
// Check for ralph-loop skill availability
try {
  Skill({ skill: "ralph-loop:ralph-loop", args: 'finish all slash commands --completion-promise "DONE"' })
} catch (e) {
  // Skill not available — skip silently, proceed to Step 2
}
```

**Important:** Strip `--ralph` and related flags (`--max-iterations`, `--completion-promise` and their values) from ARGUMENTS before passing to subsequent steps, since ralph-loop handles iteration externally.

```typescript
// Parse and strip ralph-related flags
let cleanArgs = ARGUMENTS
const RALPH_MODE = cleanArgs.includes('--ralph')

if (RALPH_MODE) {
  // Remove --ralph
  cleanArgs = cleanArgs.replace('--ralph', '')

  // Remove --max-iterations N
  cleanArgs = cleanArgs.replace(/--max-iterations\s+\d+/, '')

  // Remove --completion-promise TEXT
  cleanArgs = cleanArgs.replace(/--completion-promise\s+"[^"]*"/, '')
  cleanArgs = cleanArgs.replace(/--completion-promise\s+\S+/, '')

  cleanArgs = cleanArgs.trim()
}
```

### Step 2: Brainstorm (conditional, --brainstorm flag)

If `--brainstorm` flag is present in ARGUMENTS, run a collaborative brainstorm session before planning. Otherwise, skip directly to Step 3.

```typescript
const BRAINSTORM_FLAG = cleanArgs.includes('--brainstorm')

if (BRAINSTORM_FLAG) {
  // Strip --brainstorm from arguments
  cleanArgs = cleanArgs.replace('--brainstorm', '').trim()

  // Load and run the brainstorming skill
  Skill({ skill: "tactical-engineering:brainstorming", args: cleanArgs })

  // The brainstorm produces a document in docs/brainstorms/
  // After brainstorm completes, proceed to Step 3
  // /plan-w-team will auto-detect the brainstorm output
  console.log("Brainstorm complete. Proceeding to planning...")
}
```

### Step 3: Plan

Invoke `/plan-w-team` with the remaining arguments (feature description, `--accept path`, or `--bmad path`). When /plan-w-team presents its handoff questions, the user responds normally.

```typescript
// Invoke plan-w-team with cleaned arguments
Skill({ skill: "tactical-engineering:plan-w-team", args: cleanArgs })
```

After /plan-w-team completes, detect the generated plan path:

```typescript
// Scan specs/ directory for the most recently created/modified .md file
const specFiles = Glob({ pattern: "specs/*.md" })
// Sort by modification time, take the most recent
const PLAN_PATH = specFiles[specFiles.length - 1]  // Glob returns sorted by mtime

console.log(`Plan created at: ${PLAN_PATH}. Continuing to build...`)
```

### Step 4: Build

Invoke `/build` with the detected plan path and `--team` flag for multi-agent execution.

```typescript
// Build with team mode for maximum parallelism
Skill({ skill: "tactical-engineering:build", args: `${PLAN_PATH} --team` })

console.log("Build complete. Continuing to validation...")
```

Wait for the build to complete fully before proceeding.

### Step 5: Validate

Invoke `/validate` with the same plan path to verify the implementation meets all acceptance criteria and validation commands.

```typescript
// Run validation against the plan
Skill({ skill: "tactical-engineering:validate", args: PLAN_PATH })
```

Capture the validation result status (PASSED, FAILED, or PARTIAL) from the validate output.

### Step 6: Complete

Output a summary and done signal:

```
/get-it-done Complete!

Plan: <PLAN_PATH>
Build: Complete
Validation: <PASSED|FAILED|PARTIAL>

<promise>DONE</promise>
```

The `<promise>DONE</promise>` tag signals completion to ralph-loop if it is active.

## Key Instructions

- Run these steps in order. Do not stop between steps after planning completes — complete every step through to the end.
- The user has opted into the full autonomous workflow by invoking /get-it-done.
- After /plan-w-team completes, proceed directly to /build without additional confirmation.
- The `<promise>DONE</promise>` signal at the end is required for ralph-loop integration.
- If any step fails catastrophically (e.g., plan-w-team cannot produce a spec), stop and report the failure to the user rather than continuing with invalid state.
- The brainstorm step is the only optional interactive phase — all other steps chain automatically.

## Examples

```bash
# Basic usage - full pipeline from idea to validation
/get-it-done "Add user authentication with OAuth"

# With brainstorm phase first
/get-it-done "Build real-time chat feature" --brainstorm

# Accept an existing plan and build+validate it
/get-it-done --accept specs/my-plan.md

# Convert BMad output and build+validate
/get-it-done --bmad _bmad_output/planning-artifacts

# With ralph-loop for autonomous iteration
/get-it-done "Add dark mode support" --ralph --max-iterations 10
```
