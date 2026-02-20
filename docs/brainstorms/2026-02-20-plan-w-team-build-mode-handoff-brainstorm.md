# Brainstorm: Plan-w-Team Build Mode Handoff

**Date:** 2026-02-20
**Status:** Ready for planning

## What We're Building

A smart handoff at the end of `/plan-w-team` that detects when a spec is designed for team-mode execution and asks the user to confirm running `/build` with `--team`. Currently, the handoff always suggests plain `/build` without the `--team` flag, even when the spec contains team orchestration sections and agent-type assignments — forcing users to remember the flag themselves.

## Why This Approach

The `/plan-w-team` command produces specs with `## Team Orchestration` sections and `### Team Members` listings specifically designed for team-mode builds. But the handoff ignores this context and suggests vanilla `/build`. This creates a disconnect: the planning explicitly designs for team coordination, but the build suggestion doesn't carry that intent forward.

**Auto-detect + confirm** was chosen over two alternatives:

1. **Giving users a choice between subagent/team** — adds cognitive load for every plan, even simple ones. Most users don't need to think about execution mode.
2. **Silently defaulting to --team** — too aggressive; team mode spawns multiple Claude sessions (cost implications) and requires an experimental env var.

The confirm approach surfaces the right suggestion at the right time without surprising the user.

## Key Decisions

1. **Auto-detect team-readiness, then ask to confirm** — When the spec contains team orchestration signals, show a focused confirmation: "This spec has team orchestration — run in team mode?" rather than silently appending `--team`.

2. **Keep current behavior for non-team specs** — If no team signals are detected, the existing 4-option handoff stays exactly as-is. No mention of `--team` for simple specs.

3. **Check env var and warn proactively** — Before asking the team-mode confirmation, check whether `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set. If missing, show the export command in the confirmation description so the user can set it before proceeding. This prevents hitting the `/build` error after already committing to team mode.

4. **Cast a wide net for detection** — Check for EITHER section headings (`## Team Orchestration`, `### Team Members`) OR agent-type assignments in the task list (e.g., `Agent: backend-agent`). Either signal is sufficient to trigger the team-mode suggestion.

## Scope

### In scope
- Modify the `/plan-w-team` handoff section to detect team signals in the generated spec
- Add a focused team-mode confirmation question when signals are detected
- Check and warn about missing `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env var
- Update the "Proceed to build" option to include `--team` when user confirms

### Out of scope
- Changes to `/build` command itself
- Changes to the env var requirement
- Changes to non-team specs handoff flow
- Any new commands or agents

## Implementation Sketch

The change is isolated to `plugins/tactical-engineering/commands/plan-w-team.md`, specifically the **Handoff** section (~lines 810-849):

1. After the plan report, scan the generated spec content for team signals:
   - Heading patterns: `## Team Orchestration`, `### Team Members`
   - Task patterns: lines containing `Agent:` or `agent-type:` assignments
2. If team signals detected:
   - Check if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is in the environment
   - Show a focused `AskUserQuestion`:
     - If env var present: "This spec includes team orchestration. Run build in team mode (--team)?"
     - If env var missing: Same question, but description warns "Note: Team mode requires `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — set this before proceeding"
   - Options: "Yes, use --team" / "No, use subagent mode"
   - Then proceed to the standard handoff with the build command adjusted accordingly
3. If no team signals: standard handoff (unchanged)
