---
adr_id: ADR-003
date: 2026-02-20
status: accepted
title: Sentinel File for Cross-Process Abort
---

# ADR-003: Sentinel File for Cross-Process Abort

## Context

When a ralph loop is active, the Stop hook intercepts every session exit attempt and may block it with a continuation prompt. The user needs a reliable way to signal "stop looping" that works regardless of which process is currently executing. The abort signal must cross process boundaries: the user may issue a "stop ralph" command inside the Claude session (which writes from bash or Node.js), and the Stop hook (a separate bash process invoked by Claude Code) must detect it on the next exit attempt.

The challenge is that the Stop hook and the build command run in different process contexts. The Stop hook is a short-lived bash script invoked by Claude Code's hook infrastructure, while the build command runs within Claude's session. They share the filesystem but not memory, environment variables, or IPC channels.

## Decision

Use a **sentinel file** at `.claude/ralph-abort` as a cross-process abort signal.

The mechanism works as follows:

1. **To request abort:** The `/ralph-stop` command (or an inline "stop ralph" instruction during build) creates the file `.claude/ralph-abort`. The file contents are not significant; its existence is the signal.
2. **To detect abort:** The Stop hook checks for the file's existence (`[ -f .claude/ralph-abort ]`) early in its execution path, before any state file reads or validation checks.
3. **On abort detection:** The Stop hook sets `state.ralph.active = false` and `state.ralph.status = 'aborted'` in the state file, removes the sentinel file, and allows exit (exit 0).
4. **Cleanup:** The sentinel file is removed by whichever process detects it (Stop hook or `/continue-spec` on resume). This prevents stale abort signals from affecting future ralph loops.

## Rationale

- **Simple and reliable.** File existence checks are atomic at the OS level. There is no parsing, no format to get wrong, no partial state to worry about. The file either exists or it does not.
- **Works across all process types.** Bash scripts (`[ -f file ]`), Node.js (`fs.existsSync()`), and even manual user intervention (`touch .claude/ralph-abort`) all work identically. No special libraries or IPC setup needed.
- **No IPC complexity.** Named pipes, Unix domain sockets, signals, or shared memory would all require coordination between the short-lived Stop hook process and the long-running Claude session. A sentinel file requires zero setup and zero teardown.
- **Easy to debug.** If a user suspects the abort is not working, they can simply check whether the file exists (`ls .claude/ralph-abort`). If it exists, the next Stop hook invocation will honor it. If it does not, the abort was either already processed or never requested.
- **Consistent with existing patterns.** The `.claude/` directory already serves as the runtime state directory for the plugin (state files, specs, logs). Adding a sentinel file follows the established convention.

## Consequences

- [ ] User can abort ralph loop at any time via `/ralph-stop` command or "stop ralph" instruction
- [ ] Abort is detected on the next Stop hook invocation (not instantly mid-execution)
- [ ] Zero configuration or setup required for the abort mechanism
- [ ] Stale sentinel file from a previous run could prematurely abort a new ralph loop (mitigated by cleanup on detection and on `/continue-spec` resume)
- [ ] File creation and existence check are atomic, avoiding race conditions
- [ ] Manual abort possible via `touch .claude/ralph-abort` for debugging or emergency stop
- [ ] Sentinel file is ephemeral (cleaned up after use), does not accumulate over time

## Alternatives Considered

- **Environment variable:** Set an environment variable like `RALPH_ABORT=1` to signal abort. Rejected because environment variables do not persist across hook invocations. Each Stop hook invocation is a fresh process spawned by Claude Code; it does not inherit environment variables set within the Claude session. The signal would be lost between the command that sets it and the hook that needs to read it.
- **State file flag:** Set `state.ralph.abortRequested = true` in the state file to signal abort. Rejected due to race conditions. The Stop hook reads the state file, evaluates conditions, and then writes updates. If the abort flag is written to the state file while the Stop hook is in the middle of reading and processing, the hook may read a stale version without the flag. The sentinel file avoids this because the existence check and the state file read are independent operations -- the sentinel is checked first, before any state file I/O.
- **Unix signals (SIGUSR1/SIGUSR2):** Send a signal to the Stop hook process. Rejected because the Stop hook is a short-lived script that may not be running when the abort is requested. Signals require a known target PID and a running target process, neither of which is guaranteed in this architecture.
- **Named pipe or socket:** Create a named pipe that the Stop hook listens on. Rejected because the Stop hook is not a long-running daemon; it starts, checks, and exits within seconds. Setting up a pipe or socket for a process that lives for under 5 seconds adds complexity with no benefit over a simple file check.

## Related

- Spec: specs/native-ralph-loop-integration.md
- Tasks: Phase 3 (T8: Add abort mechanism to build.md), Phase 7 (T13: Create ralph-stop.md command)
- Key files: plugins/tactical-engineering/commands/ralph-stop.md (to be created), plugins/tactical-engineering/hooks/ralph-stop-hook.sh (to be created)
- Related ADRs: ADR-001 (Stop Hook for Ralph Loop Iteration), ADR-002 (State Schema Extension Pattern)
