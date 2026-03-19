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
  Skill({ skill: "te:brainstorming", args: cleanArgs })

  // The brainstorm produces a document in docs/brainstorms/
  // After brainstorm completes, proceed to Step 3
  // /plan-w-team will auto-detect the brainstorm output
  console.log("Brainstorm complete. Proceeding to planning...")
}
```

### Step 3: Plan

Invoke `/plan-w-team` with the remaining arguments (feature description, `--accept path`, or `--bmad path`).

```typescript
// Invoke plan-w-team with cleaned arguments
Skill({ skill: "te:plan-w-team", args: cleanArgs })
```

**CRITICAL — Plan-w-team Handoff Override:**
When `/plan-w-team` finishes and presents its handoff question ("How would you like to proceed?"), you MUST select **"Done for now"**. Do NOT select "Build with --team" or "Proceed to build" — `/get-it-done` handles the build step itself in Step 4. Selecting a build option here would cause a double-build.

After /plan-w-team completes, detect the generated plan path:

#### GATE 1: Plan File Verification

The plan MUST exist before proceeding to build. Do NOT skip this gate.

```typescript
// Scan specs/ directory for the most recently created/modified .md file
const specFiles = Glob({ pattern: "specs/*.md" })
// Sort by modification time, take the most recent
let PLAN_PATH = specFiles[specFiles.length - 1]  // Glob returns sorted by mtime

if (!PLAN_PATH) {
  // GATE 1 RETRY: Re-run plan-w-team once
  console.warn("GATE 1 WARNING: No spec file found. Retrying plan-w-team...")
  Skill({ skill: "te:plan-w-team", args: cleanArgs })

  const retryFiles = Glob({ pattern: "specs/*.md" })
  PLAN_PATH = retryFiles[retryFiles.length - 1]

  if (!PLAN_PATH) {
    console.error("GATE 1 FAILED: No spec file found after retry. Aborting pipeline.")
    // Do NOT output <promise>DONE</promise> — pipeline failed at planning
    return
  }
}

console.log(`GATE 1 PASSED: Plan exists at ${PLAN_PATH}. Continuing to build...`)
```

### Step 4: Build

Invoke `/build` with the detected plan path and `--team` flag for multi-agent execution.

```typescript
// Capture git state before build for GATE 2
const preBuildDiff = Bash({ command: "git diff --stat HEAD" })

// Build with team mode for maximum parallelism
Skill({ skill: "te:build", args: `${PLAN_PATH} --team` })

console.log("Build complete. Verifying code changes...")
```

Wait for the build to complete fully before proceeding.

#### GATE 2: Code Changes Verification

Build MUST produce actual code changes before proceeding to validation. Do NOT skip this gate.

```typescript
// Check that build actually produced code changes
const postBuildDiff = Bash({ command: "git diff --stat HEAD" })

if (postBuildDiff.trim() === '' && preBuildDiff.trim() === postBuildDiff.trim()) {
  // No new changes detected
  console.warn("GATE 2 WARNING: Build produced no code changes.")
  console.warn("This may indicate the build failed silently or the plan was already implemented.")

  AskUserQuestion({
    questions: [{
      question: "Build produced no code changes. How to proceed?",
      header: "GATE 2: No Changes Detected",
      options: [
        { label: "Continue to validation", description: "Proceed anyway — changes may have been committed during build" },
        { label: "Abort pipeline", description: "Stop here — investigate why no changes were produced" }
      ],
      multiSelect: false
    }]
  })
  // If user selects "Abort pipeline", do NOT output <promise>DONE</promise> and return
} else {
  console.log("GATE 2 PASSED: Code changes detected. Continuing to validation...")
}
```

### Step 5: Validate

Invoke `/validate` with the same plan path to verify the implementation meets all acceptance criteria and validation commands.

```typescript
// Run validation against the plan
Skill({ skill: "te:validate", args: PLAN_PATH })
```

After `/validate` completes, determine the result by reading its output:
- **PASSED**: All validation commands succeeded and all acceptance criteria met
- **PARTIAL**: Some validations passed, some failed or need manual verification
- **FAILED**: Critical validation commands failed or key acceptance criteria unmet

#### GATE 3: Validation Result Gating

Parse the validation output for the "Overall Status:" line. The `<promise>DONE</promise>` signal is strictly gated on this result.

```typescript
// Determine validation result from /validate output
// Look for "Overall Status:" line in the validation report
// PASSED = all checks green
// PARTIAL = mix of passed and failed
// FAILED = critical failures
```

### Step 6: Complete

The completion behavior depends on the validation result:

**If PASSED:**
```
/get-it-done Complete!

Plan: <PLAN_PATH>
Build: Complete
Validation: PASSED
Gates: 3/3 passed

<promise>DONE</promise>
```

**If PARTIAL:**
```
/get-it-done Complete (with warnings)

Plan: <PLAN_PATH>
Build: Complete
Validation: PARTIAL

Issues:
- <list issues from validation report>

Some criteria may need manual verification.
```

Then ask the user:
```typescript
AskUserQuestion({
  questions: [{
    question: "Validation passed partially. Signal completion or take action?",
    header: "GATE 3: Validation",
    options: [
      { label: "Signal done", description: "Output <promise>DONE</promise> and finish — remaining items are manual verification" },
      { label: "Do not signal done", description: "Stop here without signaling completion to ralph-loop" }
    ],
    multiSelect: false
  }]
})
```

Only output `<promise>DONE</promise>` if user selects "Signal done".

**If FAILED:**

Attempt one retry cycle: re-run build on failed tasks, then re-validate.

```typescript
console.warn("GATE 3 RETRY: Validation failed. Attempting recovery...")
console.warn("Re-running build to fix failed items, then re-validating...")

// Re-run build (it will detect completed tasks and only retry failed ones)
Skill({ skill: "te:build", args: `${PLAN_PATH} --team` })

// Re-validate
Skill({ skill: "te:validate", args: PLAN_PATH })

// Check result again
// If PASSED or PARTIAL after retry, follow the logic above
// If still FAILED after retry, report failure below
```

If still FAILED after retry:
```
/get-it-done FAILED

Plan: <PLAN_PATH>
Build: Complete (with retry)
Validation: FAILED
Gates: GATE 3 failed after retry

Failures:
- <list failures from validation report>

The pipeline did NOT complete successfully. Do NOT signal done.
```

Do NOT output `<promise>DONE</promise>` on failure. If ralph-loop is active, it will re-iterate automatically on the next cycle.

## Key Instructions

- Run these steps in order. Do not stop between steps after planning completes — complete every step through to the end.
- The user has opted into the full autonomous workflow by invoking /get-it-done.
- When /plan-w-team presents its handoff question, ALWAYS select "Done for now". Do NOT select any build option — /get-it-done handles the build step itself.
- After /plan-w-team completes, proceed directly to /build without additional confirmation.
- **QUALITY GATES ARE MANDATORY.** Do NOT skip any gate:
  - **GATE 1:** Plan file MUST exist in `specs/` before proceeding to build. Retry once if missing.
  - **GATE 2:** Build MUST produce code changes (verified via `git diff --stat`). Warn if no changes detected.
  - **GATE 3:** Validation result determines DONE signal. PASSED → emit. PARTIAL → ask user. FAILED → retry once, then fail without DONE.
- The `<promise>DONE</promise>` signal is ONLY output when validation PASSES (or user explicitly approves on PARTIAL). On FAILED, do NOT signal done — let ralph-loop re-iterate.
- If any step fails catastrophically (e.g., plan-w-team cannot produce a spec after retry), stop and report the failure to the user rather than continuing with invalid state.
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
