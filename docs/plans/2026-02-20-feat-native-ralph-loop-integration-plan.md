---
title: "feat: Native Ralph Loop Integration"
type: feat
status: active
date: 2026-02-20
brainstorm: docs/brainstorms/2026-02-20-ralph-loop-integration-brainstorm.md
---

# Native Ralph Loop Integration

## Overview

Build ralph-loop iteration mechanics natively into tactical-engineering commands. Three modes (`--ralph`, `--ralph --self-heal`, `--ralph` on `/plan-w-team`) give users automated iteration-until-success without depending on the external ralph-loop plugin. Completion is driven by `/validate` output, with optional `--completion-promise` as override.

## Problem Statement

Tactical-engineering workflows are one-shot: `/build` runs tasks, and if something fails, the user must manually `/retry`, `/continue-spec`, or re-run. There is no automated "keep trying until it works" mechanism. The external ralph-loop plugin solves this generically but has no understanding of multi-phase orchestration, state files, or per-task validation.

## Proposed Solution

Add `--ralph` flag to `/build` and `/plan-w-team` with three iteration modes:

| Mode | Command | What loops | Completion |
|------|---------|-----------|------------|
| Build + Validate | `/build specs/x.md --ralph` | build → validate | All validation passes |
| Self-healing | `/build specs/x.md --ralph --self-heal` | Per-task retry within build | All tasks completed |
| Full lifecycle | `/plan-w-team "..." --ralph` | plan → build → validate | All validation passes |

## Technical Approach

### Architecture

The ralph-loop is implemented as a **Stop hook** that intercepts Claude's exit attempt and decides whether to allow it or feed the prompt back. This is the same mechanism the external ralph-loop plugin uses, proven and stable.

```
Session flow:
  1. /build --ralph starts build
  2. Build executes tasks
  3. Claude tries to exit
  4. Stop hook fires:
     a. Read state file → ralph.active?
     b. Lightweight check: all tasks completed?
        - No → block exit, feed "continue build" prompt
     c. Full check: run /validate
        - Pass → allow exit (success)
        - Fail → block exit, feed "fix failures" prompt
     d. Max iterations? → allow exit + generate report
  5. Claude receives continuation prompt
  6. Repeat from step 2
```

**Stop hook contract** (proven by ralph-loop plugin):
- Receives JSON on stdin: `{ "transcript_path": "/path/to/transcript.jsonl" }`
- Returns JSON to block: `{ "decision": "block", "reason": "<continuation prompt>", "systemMessage": "<iteration status>" }`
- Returns exit 0 with no JSON to allow exit

### Implementation Phases

#### Phase 1: Foundation — State Schema & Ralph Script

**New file: `plugins/tactical-engineering/scripts/ralph-loop.js`**

Core utilities consumed by the Stop hook and build command.

```javascript
// Exported functions:
createRalphState(options)        // Create ralph state object
updateRalphIteration(specPath, iterationResult)  // Record iteration
getRalphState(state)             // Extract ralph state (or null)
isRalphComplete(state)           // Check if completion criteria met
generateFailureReport(state)     // Markdown failure report
shouldRunFullValidation(state)   // Lightweight pre-check
```

**State schema extension** (added to state-file.js `createInitialState`):

```json
{
  "ralph": {
    "active": true,
    "mode": "build-validate",
    "maxIterations": 5,
    "currentIteration": 1,
    "selfHeal": false,
    "completionPromise": null,
    "startedAt": "2026-02-20T10:00:00Z",
    "status": "active",
    "history": [
      {
        "iteration": 1,
        "startedAt": "2026-02-20T10:00:00Z",
        "completedAt": "2026-02-20T10:05:00Z",
        "tasksCompleted": 6,
        "tasksFailed": ["3", "7"],
        "tasksStuck": [],
        "validationResult": "failed",
        "validationSummary": "5/7 passed, 2 failed: integration tests, rate limiting"
      }
    ],
    "taskRetryCounters": {
      "3": 2,
      "7": 1
    },
    "failureReport": null,
    "finalResult": null
  }
}
```

**Modification to `state-file.js`:**
- Add `ralphOptions` parameter to `createInitialState()` (following `partyOptions` pattern at line 216)
- Add `updateRalphIteration(specPath, iterationResult)` export
- Add `getRalphState(state)` export
- Backward compatibility: `readStateFile` defaults missing `ralph` to `null`

**Tasks:**
- [ ] Create `scripts/ralph-loop.js` with all utility functions
- [ ] Extend `state-file.js` with ralph state creation and update functions
- [ ] Add ralph state schema to `createInitialState()`

**Relevant files:**
- `plugins/tactical-engineering/scripts/state-file.js:175` — `createInitialState` function
- `plugins/tactical-engineering/scripts/state-file.js:216-235` — Party options pattern to follow
- `plugins/tactical-engineering/scripts/state-file.js:321-333` — Exports section

---

#### Phase 2: Stop Hook — The Iteration Engine

**New file: `plugins/tactical-engineering/hooks/ralph-stop-hook.sh`**

A bash script that fires on every session exit attempt. Logic:

```bash
# 1. Read hook input from stdin (JSON with transcript_path)
# 2. Find active ralph state file:
#    - Scan .claude/specs/*/state.json for ralph.active === true
#    - If none found → exit 0 (allow normal exit)
# 3. Read state file
# 4. Check max iterations:
#    - If currentIteration >= maxIterations → generate report, exit 0
# 5. Check completion promise (if set):
#    - Read last assistant message from transcript
#    - Look for <promise>TEXT</promise> matching completionPromise
#    - If match → exit 0 (success)
# 6. Lightweight check: are all tasks in state completed or skipped?
#    - If not → increment iteration, block exit with "continue building"
# 7. Full validation: run validation commands from spec
#    - Extract "Validation Commands" section
#    - Execute each, check exit codes
#    - If all pass → exit 0 (success)
#    - If any fail → analyze failures, increment iteration, block exit
# 8. Update state file with iteration result
# 9. Return JSON: { decision: "block", reason: "<prompt>", systemMessage: "<status>" }
```

**Continuation prompt strategy:**
- If tasks incomplete: "Continue building. Focus on pending/failed tasks: [list]"
- If tasks complete but validation fails: "All tasks complete but validation failing. Fix: [specific failures]. Then re-run validation."
- Include iteration counter and remaining attempts in systemMessage

**Modify `hooks.json`:**

```json
{
  "hooks": {
    "PostToolUse": [ /* existing ruff + ty validators */ ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PLUGIN_ROOT/hooks/ralph-stop-hook.sh"
          }
        ]
      }
    ]
  }
}
```

**Tasks:**
- [ ] Create `hooks/ralph-stop-hook.sh` with full iteration logic
- [ ] Add `Stop` hook entry to `hooks/hooks.json`
- [ ] Test hook with mock state files to verify block/allow behavior

**Relevant files:**
- `plugins/tactical-engineering/hooks/hooks.json:1-21` — Current hook structure
- External reference: `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/ralph-loop/hooks/stop-hook.sh` — Proven Stop hook implementation to model from

---

#### Phase 3: Build Command — Flag Parsing & Ralph Awareness

**Modify `plugins/tactical-engineering/commands/build.md`**

Changes needed:

**3a. Argument hint and flag parsing (line 3, lines 30-50):**

Update `argument-hint` to include ralph flags:
```
argument-hint: [path-to-plan] [--team] [--ralph [--max-iterations N] [--self-heal] [--completion-promise TEXT]]
```

Parse ralph flags in Mode Detection section:
```
RALPH_MODE = arguments includes '--ralph'
MAX_ITERATIONS = parse '--max-iterations N' (default: 5, max: 50)
SELF_HEAL = arguments includes '--self-heal'
COMPLETION_PROMISE = parse '--completion-promise TEXT'
```

**Safety:** If `--ralph` without `--max-iterations`, default to 5 iterations. Print warning: "Ralph mode: max 5 iterations (use --max-iterations N to change)".

**3b. State creation (lines 199-203):**

Pass ralph options to `createInitialState`:
```javascript
createInitialState(specPath, tasks, mode, {
  ralph: RALPH_MODE ? {
    maxIterations: MAX_ITERATIONS,
    selfHeal: SELF_HEAL,
    completionPromise: COMPLETION_PROMISE
  } : null
})
```

**3c. Self-heal mode — Phase 5.5 modification (lines 496-592):**

When `SELF_HEAL` is active and a task fails validation:
- Instead of `AskUserQuestion` (current behavior), auto-retry the task
- Track retry count in `state.ralph.taskRetryCounters[taskId]`
- Per-task limit: 3 retries before marking as "stuck"
- Stuck tasks: mark status as "stuck" in state, continue to next task
- Reset per-task counters on each new ralph iteration (fresh 3 attempts)

**3d. Team mode suppression (lines 413-440):**

When `state.ralph.active === true` in team mode:
- Skip `TeamDelete()` and teammate shutdown after tasks complete
- Instead, let the Stop hook handle iteration
- Only tear down team when ralph loop is complete (final exit)
- Add "ralph team cleanup" section at the very end of the build command

**3e. Inter-iteration UX:**

Before the ralph loop continues (via Stop hook), the build command should print:
```
Ralph Loop — Iteration 3/5
  Completed: 6/8 tasks
  Failed: task 3 (integration tests), task 7 (rate limiting)
  Validation: 5/7 passed
  Retrying failed tasks...
```

**3f. User abort mechanism:**

Add instruction: "If the user says 'stop ralph' or 'abort ralph', create sentinel file `.claude/ralph-abort` and then exit normally. The Stop hook checks for this file and allows exit."

**Tasks:**
- [ ] Update build.md argument-hint and flag parsing section
- [ ] Add ralph options to state creation call
- [ ] Modify Phase 5.5 for self-heal auto-retry logic
- [ ] Add conditional team cleanup suppression for ralph mode
- [ ] Add inter-iteration status output
- [ ] Add user abort mechanism instructions
- [ ] Add ralph mode examples section

**Relevant files:**
- `plugins/tactical-engineering/commands/build.md:3` — argument-hint
- `plugins/tactical-engineering/commands/build.md:30-50` — Mode Detection
- `plugins/tactical-engineering/commands/build.md:199-203` — State creation
- `plugins/tactical-engineering/commands/build.md:413-440` — Team cleanup
- `plugins/tactical-engineering/commands/build.md:496-592` — Phase 5.5 validation
- `plugins/tactical-engineering/commands/build.md:637-655` — Phase 7 validation
- `plugins/tactical-engineering/commands/build.md:940-961` — Examples

---

#### Phase 4: Plan-w-Team — Full Lifecycle Mode

**Modify `plugins/tactical-engineering/commands/plan-w-team.md`**

When `--ralph` flag is present:
1. Plan phase executes normally (creates spec)
2. Instead of asking user "Proceed to build?", auto-invoke `/build specs/<filename>.md --ralph --max-iterations N`
3. The `--ralph` flag on build handles the iteration loop
4. Plan is considered stable — ralph only loops build→validate, never replans

**Handoff modification (lines 812-850):**

Add ralph-aware option to the handoff AskUserQuestion:
```
If --ralph flag present:
  Skip AskUserQuestion
  Auto-invoke: /build specs/<filename>.md --ralph --max-iterations <N>
  Print: "Ralph mode: auto-starting build with max N iterations"
```

**Tasks:**
- [ ] Parse `--ralph` and `--max-iterations` flags in plan-w-team
- [ ] Add auto-handoff to /build with ralph flags
- [ ] Update argument-hint to include ralph flags

**Relevant files:**
- `plugins/tactical-engineering/commands/plan-w-team.md:3` — argument-hint
- `plugins/tactical-engineering/commands/plan-w-team.md:812-850` — Handoff section

---

#### Phase 5: Continue-Spec — Ralph Resume Support

**Modify `plugins/tactical-engineering/commands/continue-spec.md`**

Add ralph-awareness after state file detection (lines 62-121):

```
After loading state:
  If state.ralph exists and state.ralph.active === true:
    Show: "Ralph loop detected: iteration N/M, status: [active|paused]"
    If state.ralph.status === 'failed' (max iterations was reached):
      Ask: "Previous ralph loop exhausted max iterations. Options:"
        1. Start new ralph loop (reset iteration counter)
        2. Resume without ralph (manual mode)
        3. Increase max iterations and continue
    Else (active/paused):
      Resume ralph loop from current iteration
      Re-enter build execution with ralph state preserved
```

**Resume parameter handling:**
- If user resumes with different `--max-iterations` than original, use the new value (command-line overrides state file)
- Print: "Resuming ralph loop from iteration N (max: M)"

**Tasks:**
- [ ] Add ralph state detection after state file load
- [ ] Add ralph resume options (new loop, manual mode, increase max)
- [ ] Handle parameter override on resume

**Relevant files:**
- `plugins/tactical-engineering/commands/continue-spec.md:62-121` — Phase 1 Detection
- `plugins/tactical-engineering/commands/continue-spec.md:134-333` — Phase 1.5 Mode branching

---

#### Phase 6: Failure Report & Status Integration

**Failure report generation** (in `scripts/ralph-loop.js`):

```markdown
## Ralph Loop Report — specs/<name>.md

**Mode:** build-validate | self-heal | full-lifecycle
**Iterations:** N/M (max reached | completed | aborted)
**Duration:** Xm Ys
**Status:** PASSED | FAILED | ABORTED

### Task Summary
| Task | Status | Retries | Last Error |
|------|--------|---------|------------|
| Setup database | completed | 0 | — |
| Integration tests | failed | 3 | Timeout connecting to test DB |

### Validation Results
| Command | Result | Output |
|---------|--------|--------|
| npm test | PASS | 42 tests passed |
| npm run lint | FAIL | 3 errors in auth.ts |

### Iteration History
| # | Tasks OK | Validation | Duration | Notes |
|---|----------|-----------|----------|-------|
| 1 | 6/8      | 5/7 FAIL  | 2m 30s   | Initial build |
| 2 | 7/8      | 6/7 FAIL  | 1m 45s   | Fixed task 3 |

### Suggested Next Steps
1. [Specific fix suggestions based on persistent failures]
2. Consider running with --self-heal for auto-retries
3. Check if validation commands themselves need updating
```

**Location:** Written to `.claude/specs/<name>/ralph-report.md` AND printed to stdout.

**Status command integration:**

Modify `commands/status.md` to read ralph state:
```
Ralph Loop: Active — iteration 3/5
  Mode: build-validate
  Self-heal: enabled (task 3: 2/3 retries used)
  Last validation: 5/7 passed
```

**Tasks:**
- [ ] Implement `generateFailureReport()` in `scripts/ralph-loop.js`
- [ ] Write report to file and stdout on completion
- [ ] Add ralph status section to `commands/status.md`

**Relevant files:**
- `plugins/tactical-engineering/commands/status.md:56-78` — Output section

---

#### Phase 7: Cancel Command & Documentation

**New skill/command: `/ralph-stop`**

Simple command that:
1. Scans `.claude/specs/*/state.json` for active ralph loops
2. Sets `state.ralph.active = false` and `state.ralph.status = 'aborted'`
3. Creates `.claude/ralph-abort` sentinel file
4. Prints: "Ralph loop aborted. Run /continue-spec to resume normally."

**Documentation updates:**
- Update `COMMANDS.md` with `--ralph` flag documentation for `/build` and `/plan-w-team`
- Add `/ralph-stop` command entry
- Update `AGENTS.md` if ralph affects agent behavior

**Tasks:**
- [ ] Create `commands/ralph-stop.md` cancel command
- [ ] Update `COMMANDS.md` with ralph documentation
- [ ] Update `AGENTS.md` if needed

**Relevant files:**
- `plugins/tactical-engineering/COMMANDS.md:133-184` — /build section
- `plugins/tactical-engineering/COMMANDS.md:219-243` — /continue-spec section

## System-Wide Impact

### Interaction Graph

```
/build --ralph
  → Creates state file with ralph field
  → Deploys agents (Task tool)
    → Agents execute tasks
    → Phase 5.5 validation hooks (existing PostToolUse)
      → Self-heal mode: auto-retry on failure
  → Claude tries to exit
  → Stop hook fires (hooks.json Stop entry)
    → Reads state file (state-file.js)
    → Lightweight check (task statuses)
    → Full validation (runs spec commands via Bash)
    → Updates ralph state (ralph-loop.js)
    → Returns block/allow decision
  → If blocked: Claude receives continuation prompt
  → Cycle repeats
```

### Error Propagation

- **Stop hook crashes**: Falls through to allow exit (safe default). State file preserved for `/continue-spec`.
- **State file corruption**: Stop hook detects, cleans up ralph state, allows exit with warning.
- **Validation command hangs**: Stop hook has timeout per command (30s default). On timeout, counts as failure.
- **Team mode teammate crash**: Lead detects via idle notification. On next iteration, respawns crashed teammate.

### State Lifecycle Risks

- **Partial state write during iteration transition**: `writeStateFile` uses `fs.writeFileSync` (atomic within OS). Risk is minimal but not zero.
- **Orphaned ralph state**: If the Stop hook is removed/disabled but state file still has `ralph.active`, `/continue-spec` will detect and offer cleanup.
- **Task status drift**: Between iterations, TaskList (in-memory) and state file (on disk) may diverge. The Stop hook uses state file as source of truth. `rebuildStateFromTaskList` handles reconciliation.

### API Surface Parity

- `/build` gains: `--ralph`, `--max-iterations`, `--self-heal`, `--completion-promise`
- `/plan-w-team` gains: `--ralph`, `--max-iterations`
- `/continue-spec` gains: ralph-aware resume
- `/status` gains: ralph iteration display
- New: `/ralph-stop` cancel command

## Acceptance Criteria

### Functional Requirements

- [ ] F1: `/build specs/x.md --ralph` loops build→validate until validation passes
- [ ] F2: `/build specs/x.md --ralph --max-iterations 3` stops after 3 iterations with failure report
- [ ] F3: `/build specs/x.md --ralph --self-heal` auto-retries failed tasks (3 per-task attempts)
- [ ] F4: `/build specs/x.md --team --ralph` persists team across iterations, reassigns failures
- [ ] F5: `/plan-w-team "..." --ralph` auto-starts build with ralph after planning
- [ ] F6: `/continue-spec specs/x.md` detects and resumes ralph loop state
- [ ] F7: `/ralph-stop` cancels active ralph loop gracefully
- [ ] F8: `--completion-promise "TEXT"` exits loop when `<promise>TEXT</promise>` detected
- [ ] F9: Default `--max-iterations` is 5 when not specified (safety default)
- [ ] F10: `PARTIAL` validation result treated as passed (manual items excluded from loop)
- [ ] F11: Failure report written to `.claude/specs/<name>/ralph-report.md` and printed

### Non-Functional Requirements

- [ ] NF1: Stop hook executes in under 5 seconds (lightweight check path)
- [ ] NF2: Full validation path completes within 60 seconds per iteration
- [ ] NF3: State file updates are atomic (no partial writes)
- [ ] NF4: No dependency on external ralph-loop plugin

### Quality Gates

- [ ] QG1: All existing `/build` tests still pass (no regression)
- [ ] QG2: Stop hook handles corrupted state files gracefully (doesn't hang)
- [ ] QG3: Ralph mode works with subagent, team, and (skipped for) party modes

## Dependencies & Risks

### Dependencies
- Claude Code Stop hook infrastructure (confirmed working via ralph-loop plugin)
- `jq` available on system (for JSON parsing in bash hook)
- Existing state-file.js and hooks.js infrastructure

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Stop hook + existing PostToolUse hooks conflict | Low | High | Separate hook types, clean separation |
| Infinite loop if max-iterations not enforced | Medium | High | Default to 5, hard max 50 |
| Token cost explosion in team+ralph mode | Medium | High | Cost warning at startup, conservative defaults |
| State file corruption between iterations | Low | Medium | Atomic writes, `rebuildStateFromTaskList` fallback |
| Self-heal retries on fundamentally broken tasks | Medium | Low | Per-task retry limit (3), stuck marking |

## Scoping Decisions

### In Scope (V1)
- `--ralph` flag on `/build` (build+validate loop)
- `--self-heal` flag (per-task auto-retry)
- `--ralph` flag on `/plan-w-team` (full lifecycle)
- `--completion-promise` flag (text-based override)
- Stop hook implementation
- State schema extensions
- Ralph-aware `/continue-spec`
- `/ralph-stop` cancel command
- Failure report generation
- `/status` integration

### Out of Scope (V1)
- Party mode + ralph (`/party --ralph`) — Party already has its own phase lifecycle
- `--ralph` on `/validate` standalone — Validation is a single check, no loop needed
- Web UI for ralph status — CLI only
- Cost estimation/budgeting — Future enhancement
- Automatic plan modification on repeated failures — Plan stays stable

## References & Research

### Internal References
- Brainstorm: `docs/brainstorms/2026-02-20-ralph-loop-integration-brainstorm.md`
- State file system: `plugins/tactical-engineering/scripts/state-file.js`
- Hook system: `plugins/tactical-engineering/hooks/hooks.json`
- Build command: `plugins/tactical-engineering/commands/build.md`
- Plan-w-team: `plugins/tactical-engineering/commands/plan-w-team.md`
- Validate command: `plugins/tactical-engineering/commands/validate.md`
- Continue-spec: `plugins/tactical-engineering/commands/continue-spec.md`

### External References
- Ralph-loop plugin (proven Stop hook pattern): `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/ralph-loop/`
- Ralph technique: https://ghuntley.com/ralph/
- Claude Code hooks documentation: Stop hook type returns `{ decision, reason, systemMessage }`

### Related Work
- Build team flag: `docs/plans/2026-02-06-feat-build-team-flag-plan.md`
- Party mode: `docs/plans/2026-02-06-feat-party-mode-command-plan.md`
- Task persistence: `docs/plans/2026-02-04-feat-task-persistence-plan.md`

## Team Orchestration

### Task Dependencies

```
Phase 1 (Foundation)
  ├── T1: Create scripts/ralph-loop.js
  ├── T2: Extend state-file.js with ralph schema
  │
Phase 2 (Stop Hook) ← depends on Phase 1
  ├── T3: Create hooks/ralph-stop-hook.sh
  ├── T4: Add Stop entry to hooks/hooks.json
  │
Phase 3 (Build Command) ← depends on Phase 1
  ├── T5: Add --ralph flag parsing to build.md
  ├── T6: Modify Phase 5.5 for self-heal auto-retry
  ├── T7: Add team cleanup suppression
  ├── T8: Add inter-iteration UX + abort mechanism
  │
Phase 4 (Plan-w-Team) ← depends on Phase 3
  ├── T9: Add --ralph flag to plan-w-team.md
  │
Phase 5 (Continue-Spec) ← depends on Phase 1
  ├── T10: Add ralph-aware resume to continue-spec.md
  │
Phase 6 (Reports & Status) ← depends on Phase 1
  ├── T11: Implement failure report in ralph-loop.js
  ├── T12: Add ralph display to status.md
  │
Phase 7 (Cancel & Docs) ← depends on Phase 2
  ├── T13: Create ralph-stop.md command
  ├── T14: Update COMMANDS.md
```

### Team Members

| Agent | Type | Tasks |
|-------|------|-------|
| backend-agent | Scripts & hooks | T1, T2, T3, T4, T11 |
| general-purpose | Command modifications | T5, T6, T7, T8, T9, T10, T12 |
| docs-agent | Documentation | T13, T14 |

### Validation Commands

```bash
# Verify ralph state schema
node -e "const s = require('./plugins/tactical-engineering/scripts/state-file.js'); const state = s.createInitialState('specs/test.md', [{id:'1',subject:'test',description:'test'}], 'subagent', {ralph:{maxIterations:5}}); console.log(JSON.stringify(state.ralph, null, 2)); process.exit(state.ralph ? 0 : 1)"

# Verify Stop hook JSON output
echo '{"transcript_path":"/tmp/test.jsonl"}' | bash plugins/tactical-engineering/hooks/ralph-stop-hook.sh

# Verify hooks.json is valid JSON with both PostToolUse and Stop entries
node -e "const h = require('./plugins/tactical-engineering/hooks/hooks.json'); console.log('PostToolUse:', !!h.hooks.PostToolUse); console.log('Stop:', !!h.hooks.Stop); process.exit(h.hooks.Stop ? 0 : 1)"

# Verify ralph-loop.js exports
node -e "const r = require('./plugins/tactical-engineering/scripts/ralph-loop.js'); ['createRalphState','updateRalphIteration','getRalphState','isRalphComplete','generateFailureReport','shouldRunFullValidation'].forEach(f => { if(!r[f]) throw new Error(f + ' missing'); }); console.log('All exports present')"
```
