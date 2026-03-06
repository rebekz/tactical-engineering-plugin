---
title: "/get-it-done Command - Full Autonomous Engineering Workflow"
type: feat
date: 2026-03-06
status: ready
origin: docs/brainstorms/2026-03-06-get-it-done-command-brainstorm.md
---

# Plan: /get-it-done Command

## Task Description

Create a `/get-it-done` command for the tactical-engineering plugin that chains the full engineering workflow into a single autonomous pipeline. Inspired by compound-engineering's `/lfg` command, this orchestrates: optional ralph-loop check, optional brainstorm, planning via `/plan-w-team`, building via `/build --team`, validation via `/validate`, and a completion signal.

The command uses model invocation (unlike LFG's `disable-model-invocation: true`) to intelligently detect the generated plan path from `/plan-w-team` output and forward it to `/build` and `/validate`. All input arguments are passed through to `/plan-w-team`, which already handles `--accept`, `--bmad`, and raw prompt inputs.

Based on brainstorm: `docs/brainstorms/2026-03-06-get-it-done-command-brainstorm.md` — all key decisions carried forward.

## Objective

1. Create a `/get-it-done` command file at `plugins/tactical-engineering/commands/get-it-done.md`
2. Register the command in the plugin's COMMANDS.md
3. Bump plugin version to reflect the new feature
4. The command must chain: ralph-check → brainstorm(optional) → plan-w-team → build --team → validate → DONE

## Relevant Files

### Existing Files (Reference)
- `plugins/tactical-engineering/commands/build.md` — Build command pattern (frontmatter, mode detection, workflow)
- `plugins/tactical-engineering/commands/validate.md` — Validate command pattern
- `plugins/tactical-engineering/commands/plan-w-team.md` — Planning command (accepts --accept, --bmad, --brainstorm, --ralph)
- `plugins/tactical-engineering/commands/party.md` — Party mode (similar full-pipeline orchestration pattern)
- `plugins/tactical-engineering/COMMANDS.md` — Command registry
- `plugins/tactical-engineering/.claude-plugin/plugin.json` — Plugin version metadata
- `.claude-plugin/marketplace.json` — Marketplace version metadata

### New Files to Create
- `plugins/tactical-engineering/commands/get-it-done.md` — The new command

### Files to Modify
- `plugins/tactical-engineering/COMMANDS.md` — Add `/get-it-done` entry
- `plugins/tactical-engineering/.claude-plugin/plugin.json` — Bump version to 0.6.0
- `.claude-plugin/marketplace.json` — Bump version to 0.6.0

## Step by Step Tasks

### 1. Create the /get-it-done command file
- **Task ID:** create-command
- **Depends On:** none
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** false

Create `plugins/tactical-engineering/commands/get-it-done.md` with:

**Frontmatter:**
```yaml
---
name: get_it_done
description: Full autonomous engineering workflow. Chains ralph-check, brainstorm, plan, build, and validate into one command.
argument-hint: [feature description | --accept path | --bmad path] [--brainstorm] [--ralph [--max-iterations N] [--completion-promise TEXT]]
model: opus
allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, NotebookEdit, WebFetch, WebSearch, AskUserQuestion, Skill, TodoWrite, TeamCreate, TeamDelete, SendMessage
---
```

**Body structure:**

1. **Variables section** — Define `ARGUMENTS` ($1..N), `BRAINSTORM_FLAG` (--brainstorm detection), `RALPH_FLAGS` (--ralph and sub-flags)

2. **Step 1: Ralph Loop Check (optional)** — Check if `ralph-loop:ralph-loop` skill is available. If yes, invoke it with completion promise "DONE". If not, skip silently and proceed.
   - Detection method: Try to reference the skill; if it doesn't exist, skip
   - Invocation: `/ralph-loop:ralph-loop "finish all slash commands" --completion-promise "DONE"`
   - Strip `--ralph` flags from `ARGUMENTS` before passing to `/plan-w-team` (since ralph-loop handles iteration, not plan-w-team's own ralph mode)

3. **Step 2: Brainstorm (conditional)** — If `--brainstorm` flag present:
   - Strip `--brainstorm` from the arguments
   - Invoke the brainstorming skill with the remaining feature description
   - The brainstorm output document path becomes context for step 3
   - If no `--brainstorm`, skip directly to step 3

4. **Step 3: Plan** — Invoke `/plan-w-team` with forwarded arguments:
   - Pass all remaining arguments (feature description, --accept, --bmad) to `/plan-w-team`
   - `/plan-w-team` will auto-detect the brainstorm document if one was just created
   - After `/plan-w-team` completes, detect the generated spec path:
     - Scan `specs/` for the most recently created/modified `.md` file
     - Store as `PLAN_PATH`
   - **Critical:** `/plan-w-team` has its own handoff questions (Part A: patterns, Part B: build options). Since we're in autonomous mode, the orchestrator should select "Build with --team" or "Proceed to build" automatically when the handoff questions appear. However, `/plan-w-team` is invoked as a Skill, so its internal AskUserQuestion calls will still be presented to the user. The orchestrator should note in the instructions that after planning completes, the flow continues automatically to build.

5. **Step 4: Build** — Invoke `/build` with the detected plan path:
   - `Skill({ skill: "tactical-engineering:build", args: "${PLAN_PATH} --team" })`
   - Uses Agent Teams for multi-agent execution
   - Wait for build to complete fully

6. **Step 5: Validate** — Invoke `/validate` with the same plan path:
   - `Skill({ skill: "tactical-engineering:validate", args: "${PLAN_PATH}" })`
   - Wait for validation to complete

7. **Step 6: Complete** — Output summary and done signal:
   ```
   /get-it-done Complete!

   Plan: <PLAN_PATH>
   Build: Complete
   Validation: <PASSED|FAILED|PARTIAL>

   <promise>DONE</promise>
   ```

**Key instruction in the command body:**
"Run these steps in order. Do not stop between steps after planning completes — complete every step through to the end. The user has opted into the full autonomous workflow by invoking /get-it-done."

**Acceptance Criteria:**
- [ ] Command file exists at `plugins/tactical-engineering/commands/get-it-done.md`
- [ ] Frontmatter follows the established command pattern
- [ ] All 6 steps are clearly documented
- [ ] Ralph-loop check is optional (skips silently if unavailable)
- [ ] Brainstorm is flag-triggered (`--brainstorm`)
- [ ] Arguments are passed through to `/plan-w-team`
- [ ] Plan path detection logic is present
- [ ] Build invoked with `--team` flag
- [ ] Completion signal includes `<promise>DONE</promise>`

### 2. Register command in COMMANDS.md
- **Task ID:** register-command
- **Depends On:** create-command
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** false

Read `plugins/tactical-engineering/COMMANDS.md` and add a `/get-it-done` entry following the existing format. Place it logically near `/party` since both are full-pipeline orchestration commands.

Entry should include:
- Command name: `/get-it-done`
- Description: Full autonomous engineering workflow
- Usage pattern with argument-hint
- Brief note about relationship to `/plan-w-team`, `/build`, `/validate`

**Acceptance Criteria:**
- [ ] `/get-it-done` is listed in COMMANDS.md
- [ ] Entry follows the existing format
- [ ] Description accurately reflects the command's purpose

### 3. Bump plugin version to 0.6.0
- **Task ID:** bump-version
- **Depends On:** create-command
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** true (can run parallel with task 2)

Update version in two files:
1. `plugins/tactical-engineering/.claude-plugin/plugin.json` — Change `"version": "0.5.2"` to `"version": "0.6.0"`
2. `.claude-plugin/marketplace.json` — Change version to `"0.6.0"`

Using 0.6.0 (minor bump) because this is a new user-facing feature.

**Acceptance Criteria:**
- [ ] `plugin.json` version is `0.6.0`
- [ ] `marketplace.json` version is `0.6.0`

## Team Orchestration

As the team lead, you have access to powerful tools for coordinating work across multiple agents. You NEVER write code directly - you orchestrate team members using these tools.

### Task Management Tools

**TaskCreate** - Create tasks in the shared task list:

```typescript
TaskCreate({
  subject: "Create /get-it-done command file",
  description: "Create the command markdown file with full workflow...",
  activeForm: "Creating get-it-done command"
})
```

**TaskUpdate** - Update task status:

```typescript
TaskUpdate({
  taskId: "1",
  status: "in_progress",
  owner: "builder"
})
```

### Team Members

#### Builder
- **Name:** builder
- **Role:** Full-stack command builder
- **Agent Type:** general-purpose
- **Resume:** true

Per planning pattern "Single Builder for Overlapping File Edits": since tasks 1 and 2 both involve command-related files, a single builder handles all tasks sequentially.

## Acceptance Criteria

### Functional Requirements
- [ ] `/get-it-done` command is callable from Claude Code
- [ ] Ralph-loop check runs first and is optional (skips if skill not installed)
- [ ] `--brainstorm` flag triggers brainstorm session before planning
- [ ] All arguments are passed through to `/plan-w-team`
- [ ] Plan path is detected after `/plan-w-team` completes
- [ ] `/build --team` is invoked with the correct plan path
- [ ] `/validate` is invoked with the correct plan path
- [ ] `<promise>DONE</promise>` is output on completion

### Non-Functional Requirements
- [ ] Command follows existing frontmatter and structure patterns
- [ ] No duplication of logic already in `/plan-w-team`, `/build`, or `/validate`

### Quality Gates
- [ ] Plugin version bumped to 0.6.0
- [ ] Command registered in COMMANDS.md

## Validation Commands

```bash
# Verify command file exists
test -f plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Command file exists" || echo "FAIL"

# Verify frontmatter contains required fields
grep -q "name: get_it_done" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Name field" || echo "FAIL"
grep -q "model: opus" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Model field" || echo "FAIL"
grep -q "allowed-tools:" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Allowed tools" || echo "FAIL"

# Verify COMMANDS.md updated
grep -q "get-it-done" plugins/tactical-engineering/COMMANDS.md && echo "PASS: COMMANDS.md updated" || echo "FAIL"

# Verify version bump
grep -q '"0.6.0"' plugins/tactical-engineering/.claude-plugin/plugin.json && echo "PASS: plugin.json version" || echo "FAIL"
grep -q '0.6.0' .claude-plugin/marketplace.json && echo "PASS: marketplace.json version" || echo "FAIL"

# Verify key content in command
grep -q "ralph-loop" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Ralph loop reference" || echo "FAIL"
grep -q "plan-w-team\|plan_w_team" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Plan reference" || echo "FAIL"
grep -q "build" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Build reference" || echo "FAIL"
grep -q "validate" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Validate reference" || echo "FAIL"
grep -q "DONE" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Done signal" || echo "FAIL"
```

## Notes

- Per planning pattern "Single Builder for Overlapping File Edits": Tasks are serialized through one builder
- Per planning pattern "Parallel Tasks Only for Independent New Files": Task 3 (version bump) can run in parallel with Task 2 since they touch different files
- The command intentionally does NOT use `disable-model-invocation: true` (unlike compound-engineering's LFG) because model reasoning is needed to detect and forward the plan path between steps

---

## Checklist Summary

### Phase 1: Implementation
- [ ] Task 1: Create /get-it-done command file
- [ ] Task 2: Register command in COMMANDS.md
- [ ] Task 3: Bump plugin version to 0.6.0
