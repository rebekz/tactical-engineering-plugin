---
adr_id: ADR-001
date: 2026-02-20
status: accepted
title: Stop Hook for Ralph Loop Iteration
---

# ADR-001: Stop Hook for Ralph Loop Iteration

## Context

Tactical-engineering workflows are one-shot: `/build` runs tasks, and if something fails the user must manually `/retry`, `/continue-spec`, or re-run. There is no automated "keep trying until it works" mechanism built into the plugin. The external ralph-loop plugin solves this generically but has no understanding of multi-phase orchestration, state files, or per-task validation. We need automated iteration in tactical-engineering builds without depending on an external plugin.

The core question is: what mechanism should drive the iteration loop? The solution must intercept Claude's session exit, evaluate whether the build is complete, and either allow exit or feed a continuation prompt back into the session.

## Decision

Use Claude Code's **Stop hook** mechanism to intercept session exit and return continuation prompts that drive the ralph loop.

The Stop hook is registered in `hooks/hooks.json` under the `Stop` key and points to a new `hooks/ralph-stop-hook.sh` script. On every session exit attempt, the hook:

1. Scans `.claude/specs/*/state.json` for an active ralph state (`ralph.active === true`)
2. If no active ralph state is found, allows normal exit (exit 0)
3. Checks whether max iterations have been reached
4. Performs a lightweight check (are all tasks completed?) and optionally a full validation check (run spec validation commands)
5. If incomplete, returns a JSON block decision: `{ "decision": "block", "reason": "<continuation prompt>", "systemMessage": "<iteration status>" }`
6. If complete or max iterations reached, allows exit and generates a failure report if needed

## Rationale

- **Proven pattern.** The external ralph-loop plugin already uses the exact same Stop hook mechanism and has been validated in production usage. We are adapting a known-working approach, not inventing one.
- **Safe defaults.** If the Stop hook crashes or encounters an error, it falls through to allow exit. This means bugs in the iteration logic never trap the user in an infinite loop. The state file is preserved for `/continue-spec` recovery.
- **No new dependencies.** The Stop hook infrastructure is built into Claude Code. No additional plugins, services, or IPC mechanisms are required.
- **Multi-phase awareness.** Unlike the generic external plugin, the native implementation can read the tactical-engineering state file directly, understand task statuses, run spec-specific validation commands, and generate targeted continuation prompts (e.g., "Focus on pending/failed tasks: [list]").
- **Clean separation of concerns.** The hook only handles the "should we continue?" decision. All build execution, task management, and validation logic remains in the existing command and script infrastructure.

## Consequences

- [ ] Automated build-validate iteration without manual user intervention
- [ ] Safe failure mode: hook crash allows normal exit, state preserved for resume
- [ ] Stop hook fires on every session exit, even non-ralph builds (must fast-path when no ralph state is active)
- [ ] Requires `jq` to be available on the system for JSON parsing in the bash hook
- [ ] Adds a new hook type (Stop) to `hooks.json` alongside existing PostToolUse hooks
- [ ] Validation command timeout needed (30s default) to prevent the hook from hanging on broken commands
- [ ] Stop hook must execute lightweight check path in under 5 seconds to avoid noticeable delay on normal exits

## Alternatives Considered

- **Polling-based iteration:** Have the build command itself loop internally, polling task status and re-running. Rejected because Claude Code has no built-in loop/poll infrastructure within a single command invocation. The command runs once and Claude exits; there is no way to re-enter the command without the Stop hook interception pattern.
- **External ralph-loop plugin dependency:** Continue relying on the separate ralph-loop plugin for iteration. Rejected because the external plugin has no awareness of tactical-engineering's multi-phase orchestration, state files, per-task validation, or self-heal retry logic. It can only do generic "keep going" prompts without understanding what specifically needs to be retried or fixed.
- **Custom IPC mechanism:** Build a separate daemon or use socket-based communication to signal continuation. Rejected as unnecessarily complex for the use case. The Stop hook provides exactly the needed semantics (intercept exit, optionally block with a prompt) without any custom infrastructure.

## Related

- Spec: specs/native-ralph-loop-integration.md
- Tasks: Phase 2 (T3: Create hooks/ralph-stop-hook.sh, T4: Add Stop entry to hooks/hooks.json)
- External reference: ralph-loop plugin Stop hook implementation (`~/.claude/plugins/marketplaces/claude-plugins-official/plugins/ralph-loop/hooks/stop-hook.sh`)
- Ralph technique origin: https://ghuntley.com/ralph/
- Related ADRs: ADR-002 (State Schema Extension Pattern), ADR-003 (Sentinel File for Cross-Process Abort)
