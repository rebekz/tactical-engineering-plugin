# Ralph Loop Native Integration

**Date:** 2026-02-20
**Status:** Draft
**Author:** AI + Human collaborative brainstorm

## What We're Building

Native ralph-loop iteration mechanics built directly into tactical-engineering commands. Instead of requiring the external ralph-loop plugin, the iteration-until-success pattern is embedded into `/build`, `/plan-w-team`, and `/validate` via `--ralph` flags.

### Problem Statement

Today, tactical-engineering workflows are one-shot: `/build` runs tasks, and if something fails, the user must manually `/retry`, `/continue-spec`, or re-run `/validate`. There's no automated "keep trying until it actually works" mechanism. The ralph-loop plugin solves this generically with a Stop hook, but it doesn't understand tactical-engineering's multi-phase orchestration, state files, or validation system.

### Solution

Three iteration modes, all triggered by `--ralph` flag on existing commands:

| Mode | Command | What loops | Completion signal |
|------|---------|-----------|-------------------|
| **Full lifecycle** | `/plan-w-team "..." --ralph --max-iterations N` | plan -> build -> validate | All validation passes |
| **Build + Validate** | `/build specs/foo.md --ralph --max-iterations N` | build -> validate | All validation passes |
| **Self-healing build** | `/build specs/foo.md --ralph --self-heal --max-iterations N` | Per-task retry within build | All tasks completed |

## Why This Approach

### Native over Composition

We chose to build iteration mechanics directly into tactical-engineering rather than composing with the external ralph-loop plugin because:

1. **Deeper integration** - The Stop hook can read state-file.js, understand task statuses, and make intelligent decisions about what to retry vs. skip
2. **Validation-aware** - Completion is driven by `/validate` output, not string-matching in Claude's text output
3. **No external dependency** - Users don't need to install a second plugin
4. **Mode-aware** - Different iteration strategies for different workflow phases (you don't retry planning the same way you retry builds)

### Validation-Driven Completion

The ralph-loop plugin uses `<promise>` tags in Claude's text output to detect completion. This is fragile for complex workflows. Instead, we use `/validate` command output as the source of truth:

- Build tasks complete? Check state file
- Acceptance criteria met? Check spec checkboxes
- Validation commands pass? Run them and check exit codes

This gives us **deterministic completion detection** rather than relying on Claude's self-assessment.

### Separate Stop Hook

The iteration Stop hook lives alongside existing PostToolUse validator hooks. Clean separation:

- **PostToolUse hooks**: Validate individual file operations (existing behavior)
- **Stop hook**: Control iteration lifecycle (new behavior)

The Stop hook only activates when `--ralph` mode is enabled (checks state file for `ralph.active: true`).

## Key Decisions

1. **Flags on existing commands** - No new `/ralph` or `/loop` command. `--ralph` flag on `/build` and `/plan-w-team` keeps the command surface small
2. **Native integration** - Own the iteration mechanics, no dependency on ralph-loop plugin
3. **Validation-driven completion** - `/validate` output determines "done", not promise tags
4. **Separate Stop hook** - New Stop hook in hooks.json, clean separation from PostToolUse
5. **Stop + report on max iterations** - When limit reached, generate failure report (what passed, what failed, what was attempted)

## Design Details

### State File Extension

Add `ralph` field to existing state file schema in `state-file.js`:

```json
{
  "build": { ... },
  "tasks": [ ... ],
  "ralph": {
    "active": true,
    "mode": "build-validate",
    "iteration": 3,
    "maxIterations": 10,
    "startedAt": "2026-02-20T10:00:00Z",
    "history": [
      {
        "iteration": 1,
        "completedTasks": 8,
        "failedTasks": 2,
        "validationResults": { "passed": 5, "failed": 2 }
      }
    ]
  }
}
```

### Stop Hook Logic

```
On session exit attempt:
  1. Read state file
  2. If ralph.active is false or missing → allow exit
  3. If ralph.iteration >= ralph.maxIterations → allow exit + generate report
  4. Run /validate checks:
     a. All validation commands pass? → allow exit (success)
     b. Some fail? → increment iteration, feed prompt back (continue loop)
  5. Update state file with iteration history
  6. Block exit with reason = "Ralph iteration N: validation incomplete"
```

### Mode Behaviors

**Full Lifecycle** (`/plan-w-team --ralph`):
1. Plan phase executes (creates spec)
2. Build phase executes (implements spec)
3. Validate phase executes (checks acceptance criteria)
4. If validate fails → restart from build phase (plan is stable)
5. Iterate until validate passes or max iterations reached

**Build + Validate** (`/build --ralph`):
1. Build phase executes
2. Validate phase executes
3. If validate fails → identify failing tasks, re-run only those + validate
4. Iterate until validate passes or max iterations reached

**Self-Healing** (`/build --ralph --self-heal`):
1. Build phase executes
2. On individual task failure → immediately retry that task
3. Per-task retry limit (3 attempts before marking as stuck)
4. Continue until all tasks pass or max iterations for the whole build

### Failure Report Format

When max iterations reached:

```markdown
## Ralph Loop Report - specs/user-auth.md

**Mode:** build-validate
**Iterations:** 10/10 (max reached)
**Status:** INCOMPLETE

### What Passed (6/8 tasks)
- [x] Setup database schema
- [x] Create user model
- [x] Implement JWT auth
- [x] Add login endpoint
- [x] Add register endpoint
- [x] Write unit tests

### What Failed (2/8 tasks)
- [ ] Integration tests - Error: Database connection timeout in CI
- [ ] Rate limiting - Error: Redis not configured

### Validation Results
- [x] Unit tests passing
- [x] Type checks clean
- [ ] Integration tests failing (3 failures)
- [ ] Rate limit tests not running

### Iteration History
| # | Tasks Done | Validation | Notes |
|---|-----------|------------|-------|
| 1 | 6/8       | 2/4        | Initial build              |
| 2 | 7/8       | 3/4        | Fixed integration timeout  |
| ...| ...      | ...        | ...                        |
| 10| 6/8       | 2/4        | Regressed on integration   |

### Suggested Next Steps
1. Fix Redis configuration for rate limiting
2. Investigate flaky integration test DB connection
3. Consider running `/build --ralph --self-heal` for targeted retries
```

## Resolved Questions

1. **Stop hook validation strategy: Lightweight check + full validate.** The Stop hook does a quick state-file check first (are all tasks marked completed?). If no → skip straight to next iteration (fast path). If yes → run full `/validate` to verify acceptance criteria. This avoids running expensive validation commands on every iteration when the build isn't even done yet.

2. **Team mode interaction: Persist team, reassign failures.** When `/build --team --ralph` is invoked, the team persists across iterations. Only failing tasks get reassigned to available teammates. This is faster and avoids the overhead of tearing down/recreating teams. Requires careful state management to track which teammates are idle vs. active.

3. **Completion promise: Yes, as optional override.** `--completion-promise` is supported alongside validation-driven completion. Useful for simple tasks that don't have formal validation commands in the spec. When both are present, either mechanism can signal completion (validation passes OR promise detected).

## References

- Ralph Loop plugin: https://ghuntley.com/ralph/
- Existing state-file.js: `plugins/tactical-engineering/scripts/state-file.js`
- Existing hooks: `plugins/tactical-engineering/hooks/hooks.json`
- Build command: `plugins/tactical-engineering/commands/build.md`
