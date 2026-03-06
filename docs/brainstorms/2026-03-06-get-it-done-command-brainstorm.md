# Brainstorm: /get-it-done Command

**Date:** 2026-03-06
**Status:** Ready for planning

## What We're Building

A full autonomous engineering workflow command (`/get-it-done`) for the tactical-engineering plugin, inspired by compound-engineering's `/lfg` and `/slfg` commands. It chains our core skills into a single end-to-end pipeline: optionally brainstorm → plan → build → validate → done.

### Motivation

Currently, users must manually invoke each step of the workflow:
1. `/plan-w-team` to create a spec
2. `/build specs/<name>.md --team` to implement
3. `/validate specs/<name>.md` to verify

This requires the user to stay present between steps, copy plan paths, and manually trigger each phase. `/get-it-done` automates this entire pipeline into a single command.

### Inspiration

- **compound-engineering `/lfg`**: Sequential autonomous workflow (plan → deepen → work → review → resolve-todos → test-browser → feature-video → DONE). Uses `disable-model-invocation: true` for pure command chaining.
- **compound-engineering `/slfg`**: Same as LFG but parallelizes review + browser-tests.
- **Our version**: Simpler, focused on our 3 core commands. Uses model invocation for intelligent plan-path handoff between steps.

## Why This Approach

### Model invocation enabled (not disabled like LFG)

Our `/plan-w-team` outputs a plan to `specs/` and `/build` needs that path as input. Rather than inventing conventions for path discovery, the orchestrator uses AI reasoning to detect the plan path and pass it to subsequent steps. More reliable, simpler to implement.

### Single command (no SLFG variant)

Our workflow is inherently sequential — build depends on plan, validate depends on build. No meaningful parallelization opportunity exists right now. One command is sufficient.

### Pass-through argument handling

All arguments are forwarded directly to `/plan-w-team`, which already handles `--accept path`, `--bmad path`, and raw prompts. No need to duplicate input parsing logic in `/get-it-done`.

### Optional brainstorm via --brainstorm flag

When `--brainstorm` flag is present, run a brainstorm session first (using the brainstorming skill), then feed results into `/plan-w-team`. Matches the existing pattern in `/plan-w-team` which already supports `--brainstorm`.

## Key Decisions

1. **Name: `/get-it-done`** — Reflects tactical-engineering's action-oriented identity
2. **Model invocation: enabled** — Needed for intelligent plan-path handoff between steps
3. **Ralph-loop: optional check** — If `ralph-loop:ralph-loop` skill exists, start it with completion promise "DONE". Skip if unavailable.
4. **Brainstorm: flag-triggered** — `--brainstorm` flag triggers brainstorm phase before planning
5. **Input modes: pass-through** — All args forwarded to `/plan-w-team` (supports --accept, --bmad, raw prompts)
6. **Completion: DONE signal + brief summary** — Output `<promise>DONE</promise>` for ralph-loop, plus plan path, build status, and validation results
7. **Single variant only** — No parallel/swarm variant needed given sequential dependencies

## Workflow

```
/get-it-done [feature description | --accept path | --bmad path] [--brainstorm] [--ralph [--max-iterations N] [--completion-promise TEXT]]
```

### Step 1: Ralph Loop Check (optional)
- Check if `ralph-loop:ralph-loop` skill exists
- If yes: start ralph-loop with completion promise "DONE"
- If no: skip, proceed to step 2

### Step 2: Brainstorm (conditional, --brainstorm flag)
- Run brainstorm session using the brainstorming skill
- Feed brainstorm output into step 3

### Step 3: Plan
- Run `/plan-w-team $ARGUMENTS`
- Detect the generated plan path from specs/ directory
- Store plan path for subsequent steps

### Step 4: Build
- Run `/build <plan-path> --team`
- Uses Agent Teams for multi-agent execution

### Step 5: Validate
- Run `/validate <plan-path>`
- Verify acceptance criteria from the plan

### Step 6: Complete
- Output brief summary (plan path, build status, validation results)
- Output `<promise>DONE</promise>` to signal ralph-loop completion

## Open Questions

None — all questions resolved during brainstorm session.

## Out of Scope

- Parallel/swarm variant (no meaningful parallelization opportunity)
- `/deepen-plan` equivalent (we don't have this skill yet)
- `/review` step (could be added later as a post-build step)
- `/compound` step (knowledge extraction — could be added as optional post-validate step)
