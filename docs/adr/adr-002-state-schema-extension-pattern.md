---
adr_id: ADR-002
date: 2026-02-20
status: accepted
title: State Schema Extension Pattern
---

# ADR-002: State Schema Extension Pattern

## Context

The ralph loop needs persistent state across iterations to track iteration count, retry counters per task, iteration history, completion status, and failure reports. This state must survive session restarts (since each Stop hook block/continue cycle may involve a new Claude session) and must be accessible to multiple consumers: the Stop hook (bash), the build command (markdown instructions read by Claude), and utility scripts (Node.js).

The existing tactical-engineering state file system (`scripts/state-file.js`) already manages per-spec build state in `.claude/specs/<name>/state.json`. It has an established extension pattern: the `partyOptions` parameter in `createInitialState()` (line 216) adds an optional `party` field to the state object when party mode is active, defaulting to `null` when not in use.

## Decision

Extend the existing `state-file.js` `createInitialState()` function with a `ralphOptions` parameter, following the established `partyOptions` pattern. When `--ralph` is passed, the state file gains a `ralph` object; when not passed, `ralph` defaults to `null`.

The ralph state schema:

```json
{
  "ralph": {
    "active": true,
    "mode": "build-validate | self-heal | full-lifecycle",
    "maxIterations": 5,
    "currentIteration": 1,
    "selfHeal": false,
    "completionPromise": null,
    "startedAt": "ISO-8601",
    "status": "active | completed | failed | aborted",
    "history": [],
    "taskRetryCounters": {},
    "failureReport": null,
    "finalResult": null
  }
}
```

New exports added to `state-file.js`:
- `updateRalphIteration(specPath, iterationResult)` -- record iteration outcome
- `getRalphState(state)` -- extract ralph state (or null)

New utility module `scripts/ralph-loop.js` provides higher-level ralph logic:
- `createRalphState(options)`, `isRalphComplete(state)`, `generateFailureReport(state)`, `shouldRunFullValidation(state)`

## Rationale

- **Consistent with existing codebase.** The `partyOptions` pattern at line 216 of `state-file.js` is the exact precedent for optional mode-specific state extensions. Following this pattern means developers familiar with the codebase immediately understand how ralph state works.
- **Backward compatible.** When `readStateFile` encounters a state file without a `ralph` field (created by older builds or non-ralph builds), it defaults to `null`. No migration needed. Existing builds are unaffected.
- **Single source of truth.** All ralph state lives in the same `state.json` file as task statuses, build metadata, and party state. The Stop hook, build command, and utility scripts all read from and write to one file, eliminating synchronization issues between separate state stores.
- **Survives session restarts.** State is written to disk via `fs.writeFileSync`, so it persists across Stop hook cycles, `/continue-spec` resumes, and system crashes.
- **Accessible from both bash and Node.js.** The state file is plain JSON, readable by `jq` in the bash Stop hook and by `require()` or `JSON.parse()` in Node.js scripts.

## Consequences

- [ ] Ralph state persists across iterations and session restarts
- [ ] No migration needed for existing state files (missing `ralph` defaults to `null`)
- [ ] Single state file serves as source of truth for all consumers (hook, command, scripts)
- [ ] State file grows larger with iteration history (each iteration adds a history entry)
- [ ] Partial state write risk during iteration transitions (mitigated by `fs.writeFileSync` atomic behavior)
- [ ] Orphaned ralph state possible if Stop hook is removed but state file retains `ralph.active` (mitigated by `/continue-spec` detecting and offering cleanup)
- [ ] Task status drift between in-memory TaskList and on-disk state between iterations (mitigated by `rebuildStateFromTaskList` reconciliation)

## Alternatives Considered

- **Separate ralph state file:** Store ralph-specific state in a dedicated file like `.claude/specs/<name>/ralph-state.json`. Rejected because this fragments the state across multiple files, requires coordinating reads and writes between two files, and diverges from the established single-state-file pattern. The existing `partyOptions` pattern proves that mode-specific extensions belong in the main state object.
- **In-memory only state:** Keep ralph iteration state in variables within the build command's execution context. Rejected because state does not survive session restarts. Each Stop hook block/continue cycle may spawn a new Claude session, and `/continue-spec` definitely starts a new session. Without disk persistence, iteration count, retry counters, and history would be lost.
- **Database or key-value store:** Use SQLite, LevelDB, or similar for ralph state. Rejected as massive over-engineering for what amounts to a single JSON object that changes once per iteration. Adds dependencies and complexity with no benefit over the existing file-based approach.

## Related

- Spec: specs/native-ralph-loop-integration.md
- Tasks: Phase 1 (T1: Create scripts/ralph-loop.js, T2: Extend state-file.js with ralph schema)
- Key files: plugins/tactical-engineering/scripts/state-file.js (lines 175, 216-235, 321-333)
- Related ADRs: ADR-001 (Stop Hook for Ralph Loop Iteration), ADR-003 (Sentinel File for Cross-Process Abort)
